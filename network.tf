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
  private_ip_google_access = true
}

# Required by every Internal Application LB in the region; the managed
# proxy infrastructure lives here.
resource "google_compute_subnetwork" "proxy_only" {
  project       = var.project_id
  name          = "${var.resource_prefix}-proxy-subnet"
  region        = var.region
  network       = google_compute_network.vpc.id
  ip_cidr_range = var.proxy_subnet_cidr
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}

# /29 is the GCP minimum. Consumer connections appear to originate from
# this range when reaching the ILB backends.
resource "google_compute_subnetwork" "psc_nat" {
  project       = var.project_id
  name          = "${var.resource_prefix}-psc-nat"
  region        = var.region
  network       = google_compute_network.vpc.id
  ip_cidr_range = var.psc_nat_subnet_cidr
  purpose       = "PRIVATE_SERVICE_CONNECT"
}

module "cloud_nat" {
  source            = "terraform-google-modules/cloud-nat/google"
  version           = "~> 5.0"
  project_id        = var.project_id
  region            = var.region
  name              = "${var.resource_prefix}-nat"
  create_router     = true
  router            = "${var.resource_prefix}-router"
  network           = google_compute_network.vpc.id
  log_config_enable = true
  log_config_filter = "ERRORS_ONLY"
}

module "firewall_rules" {
  source       = "terraform-google-modules/network/google//modules/firewall-rules"
  version      = "~> 9.0"
  project_id   = var.project_id
  network_name = google_compute_network.vpc.name

  rules = [
    {
      name                    = "${var.resource_prefix}-allow-health-checks"
      description             = "GCP load-balancer health-check probe ranges"
      direction               = "INGRESS"
      priority                = 1000
      ranges                  = ["35.191.0.0/16", "130.211.0.0/22"]
      source_tags             = null
      source_service_accounts = null
      target_tags             = null
      target_service_accounts = [google_service_account.agent.email]
      allow                   = [{ protocol = "tcp", ports = ["8080"] }]
      deny                    = []
      log_config              = null
    },
    {
      name                    = "${var.resource_prefix}-allow-lb-proxies"
      description             = "Regional managed proxies reaching agent VMs"
      direction               = "INGRESS"
      priority                = 1000
      ranges                  = [var.proxy_subnet_cidr]
      source_tags             = null
      source_service_accounts = null
      target_tags             = null
      target_service_accounts = [google_service_account.agent.email]
      allow                   = [{ protocol = "tcp", ports = ["8080"] }]
      deny                    = []
      log_config              = null
    },
    {
      name                    = "${var.resource_prefix}-allow-iap-ssh"
      description             = "Tenant admin SSH via Cloud IAP tunnel"
      direction               = "INGRESS"
      priority                = 1000
      ranges                  = ["35.235.240.0/20"]
      source_tags             = null
      source_service_accounts = null
      target_tags             = null
      target_service_accounts = [google_service_account.agent.email]
      allow                   = [{ protocol = "tcp", ports = ["22"] }]
      deny                    = []
      log_config              = null
    },
  ]
}
