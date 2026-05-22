# Tenant VPC + subnets + Cloud NAT + firewall rules.
#
# Three subnets in the workload region:
#   - workload:    where agent VMs live (private; no public IPs)
#   - proxy-only:  required by Internal Application LB infrastructure
#   - psc-nat:     where PSC service attachment NAT-translates consumer traffic
#
# All three are flagged private (no Google access by default) — VMs use
# Cloud NAT for outbound (LLM APIs, GitHub binary downloads, etc.).

resource "google_compute_network" "vpc" {
  project                 = var.project_id
  name                    = "${var.resource_prefix}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "workload" {
  project                  = var.project_id
  name                     = "${var.resource_prefix}-subnet"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = var.subnet_cidr
  private_ip_google_access = true # so VMs reach Google APIs without public IPs
}

# Required by every Internal Application LB in the region. GCP reserves this
# subnet for the managed proxy infrastructure; no user resources live here.
resource "google_compute_subnetwork" "proxy_only" {
  project       = var.project_id
  name          = "${var.resource_prefix}-proxy-subnet"
  region        = var.region
  network       = google_compute_network.vpc.id
  ip_cidr_range = var.proxy_subnet_cidr
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}

# NAT-translation subnet for the PSC service attachment. Consumer connections
# from the platform appear to originate from IPs in this range when they
# reach the ILB backends.
resource "google_compute_subnetwork" "psc_nat" {
  project       = var.project_id
  name          = "${var.resource_prefix}-psc-nat"
  region        = var.region
  network       = google_compute_network.vpc.id
  ip_cidr_range = var.psc_nat_subnet_cidr
  purpose       = "PRIVATE_SERVICE_CONNECT"
}

# Cloud NAT gives agent VMs (which have no public IPs) outbound internet
# access — necessary for LLM API calls, GitHub binary downloads, etc.
resource "google_compute_router" "router" {
  project = var.project_id
  name    = "${var.resource_prefix}-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  project                            = var.project_id
  name                               = "${var.resource_prefix}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Firewall rules. New VPCs have implicit deny-all-inbound (no rule defined
# = no traffic allowed). We open exactly the three sources that need to
# reach agent VMs on port 8080:

# 1. GCP load balancer health-check probe ranges. Used by both the L4 and
#    L7 ILB infrastructure to verify VM health.
resource "google_compute_firewall" "allow_health_checks" {
  project   = var.project_id
  name      = "${var.resource_prefix}-allow-health-checks"
  network   = google_compute_network.vpc.id
  direction = "INGRESS"
  priority  = 1000

  source_ranges = [
    "35.191.0.0/16",
    "130.211.0.0/22",
  ]

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  target_service_accounts = [google_service_account.agent.email]
}

# 2. The ILB's managed proxies, which live in the proxy-only subnet, need to
#    reach VMs on the agent port.
resource "google_compute_firewall" "allow_lb_proxies" {
  project   = var.project_id
  name      = "${var.resource_prefix}-allow-lb-proxies"
  network   = google_compute_network.vpc.id
  direction = "INGRESS"
  priority  = 1000

  source_ranges = [var.proxy_subnet_cidr]

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  target_service_accounts = [google_service_account.agent.email]
}

# 3. Cloud IAP, for `gcloud compute ssh --tunnel-through-iap` debugging
#    access by tenant admins. IAP's source range is well-known.
resource "google_compute_firewall" "allow_iap_ssh" {
  project   = var.project_id
  name      = "${var.resource_prefix}-allow-iap-ssh"
  network   = google_compute_network.vpc.id
  direction = "INGRESS"
  priority  = 1000

  source_ranges = ["35.235.240.0/20"] # Google-published IAP range

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_service_accounts = [google_service_account.agent.email]
}
