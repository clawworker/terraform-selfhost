module "psc" {
  source  = "terraform-google-modules/network/google//modules/private-service-connect-producer"
  version = "~> 18.0"

  project_id            = var.project_id
  region                = var.region
  name                  = "${var.resource_prefix}-psc"
  network               = module.network.network_id
  target_service        = google_compute_forwarding_rule.lb.id
  connection_preference = "ACCEPT_MANUAL"

  # /29 is the GCP minimum. Consumer connections appear to originate from
  # this range when reaching the ILB backends.
  nat_subnets = [
    {
      subnet_name = "${var.resource_prefix}-psc-nat"
      ipv4_range  = var.psc_nat_subnet_cidr
    },
  ]

  consumer_accept_lists = [
    {
      project_id_or_num = var.platform_project_id
      connection_limit  = 10
    },
  ]
}
