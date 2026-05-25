variable "project_id" {
  type        = string
  description = "Tenant GCP project ID."
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "Must match the platform's primary region (PSC is regional)."
}

variable "platform_project_id" {
  type        = string
  description = "Platform's GCP project ID. Added to the PSC service attachment's accept list."
}

variable "platform_sa_email" {
  type        = string
  description = "Platform control-panel SA email. Granted tokenCreator on the impersonator SA."
}

variable "resource_prefix" {
  type        = string
  default     = "cw"
  description = "Prefix for all resource names."
}

variable "subnet_cidr" {
  type        = string
  default     = "10.10.0.0/24"
  description = "Workload subnet (agent VMs)."
}

variable "proxy_subnet_cidr" {
  type        = string
  default     = "10.10.10.0/24"
  description = "Regional managed proxy subnet (required by Internal Application LB)."
}

variable "psc_nat_subnet_cidr" {
  type        = string
  default     = "10.10.20.0/29"
  description = "PSC service attachment NAT subnet. /29 is the GCP minimum."
}
