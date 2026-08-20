# Per-org content storage in the tenant's own project, so published content
# never leaves it. Artifacts are its first use.
#
# Bucket names are unique across all of GCP, so the default "{project_id}-content"
# can rarely collide with an unrelated bucket. If apply fails with "already
# exists", re-apply with -var content_bucket_name_override=<name>.
locals {
  content_bucket_name = var.content_bucket_name_override == "" ? (
    "${var.project_id}-content"
  ) : (
    var.content_bucket_name_override
  )
}

resource "google_storage_bucket" "org_content" {
  name          = local.content_bucket_name
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
