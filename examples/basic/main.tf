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
variable "content_bucket_name_override" {
  type        = string
  default     = ""
  description = "Leave empty. Set this only if apply failed because the default bucket name was already taken elsewhere on GCS."
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "clawworker" {
  source = "../.."

  project_id                   = var.project_id
  region                       = var.region
  platform_project_id          = var.platform_project_id
  platform_sa_email            = var.platform_sa_email
  content_bucket_name_override = var.content_bucket_name_override
}

output "content_bucket_name" {
  value = module.clawworker.content_bucket_name
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
    content_bucket_name    = module.clawworker.content_bucket_name
  }
}
