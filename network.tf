module "network" {
  source       = "terraform-google-modules/network/google"
  version      = "~> 18.0"
  project_id   = var.project_id
  network_name = "${var.resource_prefix}-vpc"
  routing_mode = "REGIONAL"

  subnets = [
    {
      subnet_name           = "${var.resource_prefix}-subnet"
      subnet_ip             = var.subnet_cidr
      subnet_region         = var.region
      subnet_private_access = "true"
    },
    # Required by every Internal Application LB in the region; the managed
    # proxy infrastructure lives here.
    {
      subnet_name   = "${var.resource_prefix}-proxy-subnet"
      subnet_ip     = var.proxy_subnet_cidr
      subnet_region = var.region
      purpose       = "REGIONAL_MANAGED_PROXY"
      role          = "ACTIVE"
    },
  ]
}

module "cloud_nat" {
  source            = "terraform-google-modules/cloud-nat/google"
  version           = "~> 7.0"
  project_id        = var.project_id
  region            = var.region
  name              = "${var.resource_prefix}-nat"
  create_router     = true
  router            = "${var.resource_prefix}-router"
  network           = module.network.network_id
  log_config_enable = true
  log_config_filter = "ERRORS_ONLY"
}

module "firewall_rules" {
  source       = "terraform-google-modules/network/google//modules/firewall-rules"
  version      = "~> 18.0"
  project_id   = var.project_id
  network_name = module.network.network_name

  ingress_rules = [
    {
      name                    = "${var.resource_prefix}-allow-health-checks"
      description             = "GCP load-balancer health-check probe ranges"
      source_ranges           = ["35.191.0.0/16", "130.211.0.0/22"]
      target_service_accounts = [google_service_account.agent.email]
      allow                   = [{ protocol = "tcp", ports = ["8080"] }]
    },
    {
      name                    = "${var.resource_prefix}-allow-lb-proxies"
      description             = "Regional managed proxies reaching agent VMs"
      source_ranges           = [var.proxy_subnet_cidr]
      target_service_accounts = [google_service_account.agent.email]
      allow                   = [{ protocol = "tcp", ports = ["8080"] }]
    },
    {
      name                    = "${var.resource_prefix}-allow-iap-ssh"
      description             = "Tenant admin SSH via Cloud IAP tunnel"
      source_ranges           = ["35.235.240.0/20"]
      target_service_accounts = [google_service_account.agent.email]
      allow                   = [{ protocol = "tcp", ports = ["22"] }]
    },
  ]
}

# Convenience local: the workload subnet is referenced from ilb.tf for the
# forwarding rule. The network module returns subnets keyed by region/name.
locals {
  workload_subnet_key = "${var.region}/${var.resource_prefix}-subnet"
  proxy_subnet_key    = "${var.region}/${var.resource_prefix}-proxy-subnet"
}
