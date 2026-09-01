# Bucket names are unique across ALL of GCS, so the default can already be
# taken. Apply then 409s on this bucket; set the override and re-apply.
locals {
  content_bucket_name = var.content_bucket_name_override == "" ? (
    "${var.project_id}-content"
  ) : (
    var.content_bucket_name_override
  )
}

# Holds artifacts published from agents in this project, so published content
# never leaves the tenant boundary.
resource "google_storage_bucket" "org_content" {
  name     = local.content_bucket_name
  location = var.region
  project  = var.project_id

  force_destroy               = false
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  depends_on = [module.apis]
}

# Scoped to this bucket so the impersonator can read and write ONLY published
# artifacts, not any other bucket in the project.
resource "google_storage_bucket_iam_member" "impersonator_content_admin" {
  bucket = google_storage_bucket.org_content.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.impersonator.email}"
}
