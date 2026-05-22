variable "project_id" {
  type        = string
  description = "Tenant GCP project ID where agent VMs will run. The caller must have Owner / Editor + Project IAM Admin in this project."
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "GCE region for agent VMs and the regional Internal Application Load Balancer. MUST match the platform's primary region — PSC is regional and consumer endpoints (platform-side) and service attachments (tenant-side) must agree."
}

variable "platform_project_id" {
  type        = string
  description = "Platform's GCP project ID. Added to the PSC service attachment's accept list so only the platform can consume it. Find this in the clawworker onboarding wizard."
}

variable "platform_sa_email" {
  type        = string
  description = "The platform control-panel service account email. Granted roles/iam.serviceAccountTokenCreator on the impersonator SA — this is the single binding that lets the platform impersonate the in-project SA. Removing this binding (e.g., via `terraform destroy -target=google_service_account_iam_member.platform_can_impersonate`) is the one-click revocation lever."
}

variable "resource_prefix" {
  type        = string
  default     = "cw"
  description = "Prefix for all resource names. Change only if running multiple isolated installations in the same project."
}

variable "subnet_cidr" {
  type        = string
  default     = "10.10.0.0/24"
  description = "CIDR for the agent VM subnet. Must not overlap with other ranges in the project."
}

variable "proxy_subnet_cidr" {
  type        = string
  default     = "10.10.10.0/24"
  description = "CIDR for the regional managed proxy subnet (required by Internal Application LB). Separate from subnet_cidr."
}

variable "psc_nat_subnet_cidr" {
  type        = string
  default     = "10.10.20.0/29"
  description = "CIDR for the PSC service attachment NAT subnet. /29 (8 addresses) is the GCP minimum."
}
