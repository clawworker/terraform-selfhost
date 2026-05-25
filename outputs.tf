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
  value = google_compute_network.vpc.name
}

output "subnet" {
  value = google_compute_subnetwork.workload.name
}

output "url_map_name" {
  value = google_compute_region_url_map.lb.name
}

output "health_check_name" {
  value = google_compute_region_health_check.lb.name
}

output "psc_connection_uri" {
  value = google_compute_service_attachment.psc.id
}
