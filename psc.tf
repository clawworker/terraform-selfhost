resource "google_compute_service_attachment" "psc" {
  project = var.project_id
  name    = "${var.resource_prefix}-psc"
  region  = var.region

  target_service        = google_compute_forwarding_rule.lb.id
  connection_preference = "ACCEPT_MANUAL"
  enable_proxy_protocol = false

  nat_subnets = [google_compute_subnetwork.psc_nat.id]

  consumer_accept_lists {
    project_id_or_num = var.platform_project_id
    connection_limit  = 10
  }
}
