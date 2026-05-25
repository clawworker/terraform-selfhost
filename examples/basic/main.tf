terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.11"
    }
  }
}

variable "project_id" { type = string }
variable "region" { type = string }
variable "platform_project_id" { type = string }
variable "platform_sa_email" { type = string }

provider "google" {
  project = var.project_id
  region  = var.region
}

module "clawworker" {
  source = "../.."

  project_id          = var.project_id
  region              = var.region
  platform_project_id = var.platform_project_id
  platform_sa_email   = var.platform_sa_email
}

# Pass these to the ClawWorker onboarding wizard. Run:
#   terraform output -json onboarding_payload
output "onboarding_payload" {
  value = {
    gcp_project_id         = module.clawworker.project_id
    impersonation_sa_email = module.clawworker.impersonator_sa_email
    agent_sa_email         = module.clawworker.agent_sa_email
    region                 = module.clawworker.region
    network                = module.clawworker.network
    subnet                 = module.clawworker.subnet
    url_map_name           = module.clawworker.url_map_name
    health_check_name      = module.clawworker.health_check_name
    psc_connection_uri     = module.clawworker.psc_connection_uri
  }
}
