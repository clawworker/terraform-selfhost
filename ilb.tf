# Per-tenant regional Internal Application Load Balancer.
#
# The URL map starts as a skeleton with no host_rules — agent VMs aren't
# attached yet (that's the platform's job at provision time, in a later
# phase). The platform impersonates the SA and ADDS host_rules pointing
# `<agent>.<org_slug>.<platform_domain>` at per-VM backend services it also
# creates. Removing an agent reverses the same lifecycle.

resource "google_compute_region_health_check" "lb" {
  project = var.project_id
  name    = "${var.resource_prefix}-health"
  region  = var.region

  http_health_check {
    port         = 8080
    request_path = "/health"
  }

  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3
}

# Stub backend service that the URL map defaults to until the platform
# attaches real per-VM backends via host_rules. Has no NEGs — requests
# routed here return 502, which is the right signal for "host doesn't
# match any configured rule." Per-VM backend services with real NEGs are
# created at agent-provision time and inserted into the URL map.
resource "google_compute_region_backend_service" "stub" {
  project               = var.project_id
  name                  = "${var.resource_prefix}-default-stub"
  region                = var.region
  protocol              = "HTTP"
  load_balancing_scheme = "INTERNAL_MANAGED"
  health_checks         = [google_compute_region_health_check.lb.id]
}

resource "google_compute_region_url_map" "lb" {
  project         = var.project_id
  name            = "${var.resource_prefix}-url-map"
  region          = var.region
  default_service = google_compute_region_backend_service.stub.id
}

resource "google_compute_region_target_http_proxy" "lb" {
  project = var.project_id
  name    = "${var.resource_prefix}-http-proxy"
  region  = var.region
  url_map = google_compute_region_url_map.lb.id
}

# Static internal IP for the ILB frontend. PSC service attachment targets
# THIS forwarding rule via the IP/port the LB listens on.
resource "google_compute_address" "lb" {
  project      = var.project_id
  name         = "${var.resource_prefix}-lb-ip"
  region       = var.region
  subnetwork   = google_compute_subnetwork.workload.id
  address_type = "INTERNAL"
  purpose      = "GCE_ENDPOINT"
}

resource "google_compute_forwarding_rule" "lb" {
  project               = var.project_id
  name                  = "${var.resource_prefix}-lb"
  region                = var.region
  network               = google_compute_network.vpc.id
  subnetwork            = google_compute_subnetwork.workload.id
  ip_address            = google_compute_address.lb.address
  ip_protocol           = "TCP"
  port_range            = "80"
  load_balancing_scheme = "INTERNAL_MANAGED"
  target                = google_compute_region_target_http_proxy.lb.id

  # Proxy-only subnet must exist before the forwarding rule can attach.
  depends_on = [google_compute_subnetwork.proxy_only]
}
