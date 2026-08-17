output "project_id" {
  value = var.project_id
}

output "impersonator_sa_email" {
  value = google_service_account.impersonator.email
}

output "agent_sa_email" {
  value = google_service_account.agent.email
}

output "region" {
  value = var.region
}

output "network" {
  value = module.network.network_name
}

output "subnet" {
  value = module.network.subnets[local.workload_subnet_key].name
}

output "url_map_name" {
  value = google_compute_region_url_map.lb.name
}

output "health_check_name" {
  value = google_compute_region_health_check.lb.name
}

output "psc_connection_uri" {
  value = module.psc.service_attachment_id
}

# For the tenant's own verification. Not part of onboarding_payload: the platform
# derives this name, so there is nothing to paste.
output "content_bucket_name" {
  value       = google_storage_bucket.org_content.name
  description = "Bucket holding this org's published artifacts."
}
