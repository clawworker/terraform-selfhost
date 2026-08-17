# Per-org content storage in the tenant's own project, so published content
# never leaves it. Artifacts are its first use.
#
# The name is not configurable — the platform derives "{project_id}-content" from
# the project id it already holds, so a variable here could only drift out of step.
resource "google_storage_bucket" "org_content" {
  name          = "${var.project_id}-content"
  location      = var.region
  project       = var.project_id
  force_destroy = false

  uniform_bucket_level_access = true

  # The platform serves every artifact through a short-lived signed URL, so no
  # object here ever needs to be world-readable.
  public_access_prevention = "enforced"

  depends_on = [module.apis]
}

# Scoped to this bucket, not the project: the impersonator already holds
# project-level compute roles, and storage has no reason to be that wide.
resource "google_storage_bucket_iam_member" "impersonator_content_admin" {
  bucket = google_storage_bucket.org_content.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.impersonator.email}"
}
