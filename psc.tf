# Private Service Connect: the cross-project network handoff.
#
# The platform "consumes" this service attachment from its own VPC by
# creating a regional forwarding rule (consumer endpoint) whose `target` is
# this attachment's URI. After PSC propagation (~30-60s), the consumer
# endpoint has an IP in the platform's VPC that, when traffic is sent to
# it, NATs into THIS subnet (psc_nat) and forwards to the ILB.
#
# ACCEPT_MANUAL with `consumer_accept_lists` set to the platform's project
# ID means only the platform can connect. Auto-accept would be open to
# anyone who knew the URI.

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
