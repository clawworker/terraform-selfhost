# terraform-selfhost

Terraform module that provisions the GCP-side infrastructure for hosting ClawWorker agents in your own Google Cloud project. The platform (control-panel) reaches into your project via service-account impersonation and a Private Service Connect endpoint — no long-lived secrets, no shared VPC, fully revocable.

## What this creates

In your GCP project:

- **Two service accounts**:
  - `cw-control-panel-impersonator` — the platform impersonates this SA to manage your agent VMs.
  - `cw-agent` — your agent VMs run as this SA.
- **Project IAM**: the impersonator gets `roles/compute.instanceAdmin.v1` and `roles/compute.loadBalancerAdmin`. Nothing else.
- **One IAM grant to the platform**: the platform's control-panel SA gets `roles/iam.serviceAccountTokenCreator` on `cw-control-panel-impersonator`. **This is the only permission the platform holds in your project.** Remove it to revoke access instantly.
- **VPC + subnets**: workload subnet for VMs, proxy-only subnet for the Internal LB, and a NAT subnet for the PSC service attachment.
- **Cloud NAT**: outbound internet for agent VMs (so they can call LLM APIs etc. without public IPs).
- **Three firewall rules**: GCP load-balancer health-check ranges, the LB proxy subnet, and Cloud IAP for SSH debugging. Everything else is denied (VPC default).
- **Internal Application Load Balancer**: skeleton with no host-rules yet — the platform adds per-VM rules at agent-provision time.
- **PSC Service Attachment** in `ACCEPT_MANUAL` mode, accepting only the platform's project ID.
- **One Cloud Storage bucket**, `{your-project-id}-content`: holds artifacts published from your agents. Public access prevention enforced; the impersonator gets `roles/storage.objectAdmin` scoped to this bucket only.

Nothing is created in the platform's project; nothing is created outside the region you specify.

## Tenant prerequisites

- A GCP project where you have `Owner` (easiest) or `Editor` + `Project IAM Admin` + `Service Usage Admin` (the last is needed for the module to enable required APIs on your behalf).
- Local Terraform >= 1.5 and `gcloud auth application-default login` completed.
- The **platform project ID** and **platform SA email** from the ClawWorker onboarding wizard.

The module enables the GCP APIs it needs on your project automatically (`compute`, `iam`, `iamcredentials`, `servicenetworking`). It does **not** disable them on `terraform destroy` — your other workloads using those APIs aren't affected by a teardown of this module.

## Usage

```hcl
module "clawworker" {
  source  = "github.com/clawworker/terraform-selfhost?ref=v0.1.0"

  project_id          = "my-tenant-project"
  region              = "us-central1"           # must match the platform's region
  platform_project_id = "clawworker-ai"         # from onboarding wizard
  platform_sa_email   = "control-panel-sa@clawworker-ai.iam.gserviceaccount.com"
}

output "clawworker_outputs" {
  value = {
    project_id            = module.clawworker.project_id
    impersonator_sa_email = module.clawworker.impersonator_sa_email
    agent_sa_email        = module.clawworker.agent_sa_email
    region                = module.clawworker.region
    network               = module.clawworker.network
    subnet                = module.clawworker.subnet
    url_map_name          = module.clawworker.url_map_name
    health_check_name     = module.clawworker.health_check_name
    psc_connection_uri    = module.clawworker.psc_connection_uri
  }
}
```

Apply it:

```
terraform init
terraform plan
terraform apply
```

Then paste the outputs (`terraform output clawworker_outputs`) into the ClawWorker onboarding wizard. The platform validates connectivity, creates its consumer PSC endpoint, and flips your org to self-hosted mode.

There's a minimal working example in [`examples/basic/`](examples/basic).

## Costs

Tenant pays GCP directly. Approximate steady-state, US region:

| Resource | Rate | Monthly fixed |
|---|---|---|
| Internal Application LB forwarding rule | $0.025/hour | ~$18 |
| Cloud NAT gateway | $0.044/hour | ~$32 |
| **Fixed subtotal** | | **~$50/month** |
| GCE VM compute | varies | per machine type (e2-small ~$14, e2-medium ~$28) |
| Cloud NAT egress + data processing | $0.045/GB + $0.045/GB | **significant for high-token workloads** |
| ILB data processing | $0.008/GB | both directions |

For 10 e2-small agents at light traffic, expect ~$200/month total. High-token agents (100GB+/month each) push NAT egress cost above compute cost — surface this for cost-conscious tenants.

## Revocation

To revoke platform access **without tearing down infrastructure**:

```
terraform destroy -target=google_service_account_iam_member.platform_can_impersonate
```

This removes the `tokenCreator` binding. The platform's next API call returns `PermissionDenied`; new agent provisioning is blocked. **Existing agent VMs keep running** as `cw-agent` — they aren't affected by impersonator revocation.

Artifact publishing uses the same binding, so it stops too. Already-published artifacts stay in your bucket.

To re-enable access, `terraform apply` again.

For full teardown: `terraform destroy`. The platform's PSC consumer endpoint is in the platform's project (it remains there until the platform tears it down on org deletion).

`terraform destroy` stops with `bucket is not empty` while published artifacts remain, rather than deleting them. Empty the bucket first:

```
gsutil -m rm -r gs://$(terraform output -raw content_bucket_name)/**
```

## Audit visibility

Every action the platform takes in your project surfaces in your Cloud Audit Logs:

- **Actor** (resource being acted on): `cw-control-panel-impersonator@<your-project>.iam.gserviceaccount.com`
- **Authentication info** (who impersonated): `control-panel-sa@<platform-project>.iam.gserviceaccount.com`

To watch in real time:
```
gcloud logging tail "protoPayload.authenticationInfo.principalSubject:cw-control-panel-impersonator" --project <your-project>
```

The platform never makes API calls in your project under any other identity.

## Versioning

This module follows semver. Pin to a tag (`ref=v0.1.0`) in production. The platform's onboarding wizard documents the minimum module version required.

## Support

Issues / discussions: this repo. For the platform side or onboarding wizard questions, file in `clawworker/control-panel`.
