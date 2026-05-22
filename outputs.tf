output "project_id" {
  value       = var.project_id
  description = "Pass to the clawworker onboarding wizard as `gcp_project_id`."
}

output "impersonator_sa_email" {
  value       = google_service_account.impersonator.email
  description = "Pass as `impersonation_sa_email`. The platform impersonates THIS SA to act in your project."
}

output "agent_sa_email" {
  value       = google_service_account.agent.email
  description = "Pass as `agent_sa_email`. Your agent VMs run AS this SA."
}

output "region" {
  value       = var.region
  description = "Pass as `region`. Must match the platform's primary region."
}

output "network" {
  value       = google_compute_network.vpc.name
  description = "Pass as `network`."
}

output "subnet" {
  value       = google_compute_subnetwork.workload.name
  description = "Pass as `subnet`."
}

output "url_map_name" {
  value       = google_compute_region_url_map.lb.name
  description = "Pass as `url_map_name`. Platform manages per-VM host_rules in this URL map at provision time."
}

output "health_check_name" {
  value       = google_compute_region_health_check.lb.name
  description = "Pass as `health_check_name`. Used as the default for per-VM backend services."
}

output "psc_connection_uri" {
  value       = google_compute_service_attachment.psc.id
  description = "Pass as `psc_connection_uri`. Platform creates its PSC consumer endpoint targeting this URI."
}
