# Enable required Google APIs in the tenant project. Every resource and
# child module that targets the tenant project carries depends_on = [module.apis]
# (or inherits via output references) so the first `terraform apply` doesn't
# race the API enablement and fail with "API not enabled" errors.
#
# disable_services_on_destroy defaults to TRUE in this submodule. We override
# to false: a tenant's `terraform destroy` of THIS module shouldn't tear down
# project-wide APIs that other tenant infrastructure may rely on.
module "apis" {
  source                      = "terraform-google-modules/project-factory/google//modules/project_services"
  version                     = "~> 18.0"
  project_id                  = var.project_id
  disable_services_on_destroy = false
  disable_dependent_services  = false

  activate_apis = [
    "compute.googleapis.com",           # everything in network.tf, ilb.tf, psc.tf
    "iam.googleapis.com",               # service accounts + IAM bindings
    "iamcredentials.googleapis.com",    # platform impersonates impersonator SA at runtime
    "servicenetworking.googleapis.com", # PSC producer infrastructure
  ]
}
