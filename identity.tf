# The two service accounts that define the platform↔tenant trust boundary.
#
# - `impersonator`: the SA the platform impersonates when acting in this
#   project. Has the project-level roles agents need (compute admin + load
#   balancer admin). The platform never holds keys to this SA — it mints
#   short-lived tokens on demand via the IAM Credentials API, gated by the
#   tokenCreator binding below.
#
# - `agent`: the SA each agent VM runs as. No project-level roles by default
#   (agents only need minimal scopes set at VM-creation time). The
#   impersonator gets serviceAccountUser on this specific SA so it can attach
#   `agent` to VMs during provisioning.

resource "google_service_account" "impersonator" {
  project      = var.project_id
  account_id   = "${var.resource_prefix}-control-panel-impersonator"
  display_name = "ClawWorker control-panel impersonator"
  description  = "Platform impersonates this SA via IAM Credentials API. Removing the platform_can_impersonate binding revokes access."
}

resource "google_service_account" "agent" {
  project      = var.project_id
  account_id   = "${var.resource_prefix}-agent"
  display_name = "ClawWorker agent runtime"
  description  = "Attached to agent VMs. No project-level roles by default."
}

# Project-level roles for the impersonator. These define everything the
# platform can do in your project via impersonation.
#
# Why these and not more:
#   - compute.instanceAdmin.v1: create/get/start/stop/delete VMs, set
#     metadata, use subnets. The "v1" variant excludes IAM and shared VPC
#     management.
#   - compute.loadBalancerAdmin: manage backend services + NEGs + URL map
#     entries (per-VM, attached when agents are provisioned). Does NOT
#     include firewall management — those are static, baked here.
#
# Notably absent: editor, owner, projectIamAdmin, serviceAccountAdmin,
# dns.admin, secretmanager.admin, storage.admin. The platform never touches
# any of these.

resource "google_project_iam_member" "impersonator_compute" {
  project = var.project_id
  role    = "roles/compute.instanceAdmin.v1"
  member  = "serviceAccount:${google_service_account.impersonator.email}"
}

resource "google_project_iam_member" "impersonator_load_balancer" {
  project = var.project_id
  role    = "roles/compute.loadBalancerAdmin"
  member  = "serviceAccount:${google_service_account.impersonator.email}"
}

# Lets the impersonator attach `agent` SA to VMs at creation time.
# Scoped to the agent SA resource — NOT a project-level grant, so the
# impersonator cannot attach OTHER SAs in the project.
resource "google_service_account_iam_member" "impersonator_act_as_agent" {
  service_account_id = google_service_account.agent.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.impersonator.email}"
}

# THE binding that grants the platform anything at all.
#
# The platform's control-panel SA gets roles/iam.serviceAccountTokenCreator
# on the impersonator SA — this is the permission needed to call
# iamcredentials.GenerateAccessToken and receive a short-lived (1h) access
# token that authenticates as the impersonator SA.
#
# Revocation: `terraform destroy -target=google_service_account_iam_member.platform_can_impersonate`
# removes this binding and the platform loses access immediately. The rest of
# the infrastructure (VPC, ILB, SAs) stays in place; agents continue running
# but the platform can't manage them until the binding is restored.
resource "google_service_account_iam_member" "platform_can_impersonate" {
  service_account_id = google_service_account.impersonator.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${var.platform_sa_email}"
}
