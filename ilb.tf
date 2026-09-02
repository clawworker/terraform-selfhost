resource "google_compute_region_health_check" "lb" {
  project = var.project_id
  name    = "${var.resource_prefix}-health"
  region  = var.region

  http_health_check {
    port = 8080
    # The clawworker agent registers ONLY /healthz (+ /readyz) — there is no
    # /health route. Probing /health returns 404, leaving every backend
    # permanently UNHEALTHY → the ILB serves 503 "no healthy upstream" on every
    # agent URL even when the agent is fine.
    request_path = "/healthz"
  }

  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  depends_on = [module.apis]
}

# Stub backend with no NEGs. URL maps require a default; this returns 502
# for any unmatched host_rule, which is the right signal for "no agent at
# this hostname." Per-VM backends + host_rules are added by the platform
# at agent-provision time.
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

  # The Commandlyne owns per-agent routes created at runtime.
  lifecycle {
    ignore_changes = [
      host_rule,
      path_matcher,
    ]
  }
}

resource "google_compute_region_target_http_proxy" "lb" {
  project = var.project_id
  name    = "${var.resource_prefix}-http-proxy"
  region  = var.region
  url_map = google_compute_region_url_map.lb.id
}

resource "google_compute_address" "lb" {
  project      = var.project_id
  name         = "${var.resource_prefix}-lb-ip"
  region       = var.region
  subnetwork   = module.network.subnets[local.workload_subnet_key].id
  address_type = "INTERNAL"
  purpose      = "GCE_ENDPOINT"

  # subnetwork ref above implicitly waits for module.network → module.apis,
  # but the address is otherwise an APIs-dependent compute resource that
  # could exist independently of the subnet. Keep the explicit edge.
  depends_on = [module.apis]
}

resource "google_compute_forwarding_rule" "lb" {
  project               = var.project_id
  name                  = "${var.resource_prefix}-lb"
  region                = var.region
  network               = module.network.network_id
  subnetwork            = module.network.subnets[local.workload_subnet_key].id
  ip_address            = google_compute_address.lb.address
  ip_protocol           = "TCP"
  port_range            = "80"
  load_balancing_scheme = "INTERNAL_MANAGED"
  target                = google_compute_region_target_http_proxy.lb.id

  # Proxy-only subnet must exist before the forwarding rule attaches.
  depends_on = [module.network]
}
