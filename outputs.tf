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

output "content_bucket_name" {
  value       = google_storage_bucket.org_content.name
  description = "Bucket holding this org's published artifacts."
}

# The exact shape the onboarding wizard accepts. Composed here rather than by
# each caller so the key names stay owned by the module that produces them.
output "onboarding_payload" {
  description = "Paste into the onboarding wizard: terraform output -json onboarding_payload"
  value = {
    gcp_project_id         = var.project_id
    impersonation_sa_email = google_service_account.impersonator.email
    agent_sa_email         = google_service_account.agent.email
    region                 = var.region
    network                = module.network.network_name
    subnet                 = module.network.subnets[local.workload_subnet_key].name
    url_map_name           = google_compute_region_url_map.lb.name
    health_check_name      = google_compute_region_health_check.lb.name
    psc_connection_uri     = module.psc.service_attachment_id
    content_bucket_name    = google_storage_bucket.org_content.name
  }
}
