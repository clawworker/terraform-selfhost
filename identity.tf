resource "google_service_account" "impersonator" {
  project      = var.project_id
  account_id   = "${var.resource_prefix}-control-panel-impersonator"
  display_name = "ClawWorker control-panel impersonator"
  description  = "Platform impersonates this SA via IAM Credentials API. Removing platform_can_impersonate revokes access."

  depends_on = [module.apis]
}

resource "google_service_account" "agent" {
  project      = var.project_id
  account_id   = "${var.resource_prefix}-agent"
  display_name = "ClawWorker agent runtime"

  depends_on = [module.apis]
}

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

# Scoped to the agent SA resource so the impersonator can attach ONLY this
# SA to VMs, not any other SA in the project.
resource "google_service_account_iam_member" "impersonator_act_as_agent" {
  service_account_id = google_service_account.agent.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.impersonator.email}"
}

# The one binding granting the platform anything in this project. Revoke
# with: terraform destroy -target=google_service_account_iam_member.platform_can_impersonate
resource "google_service_account_iam_member" "platform_can_impersonate" {
  service_account_id = google_service_account.impersonator.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${var.platform_sa_email}"
}
