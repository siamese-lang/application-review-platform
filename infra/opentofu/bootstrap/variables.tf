variable "project_id" {
  type = string
}

variable "admin_oslogin_members" {
  description = "Owner-controlled user:/group: principals that may use IAP + OS Admin Login and perform the initial runtime apply."
  type        = set(string)
  default     = []
}

variable "github_repository_owner" {
  description = "Exact GitHub owner trusted by the deployment identity provider."
  type        = string
  default     = "siamese-lang"
}

variable "github_repository" {
  description = "Exact owner/repository trusted by the deployment identity provider."
  type        = string
  default     = "siamese-lang/application-review-platform"
}

variable "github_deployment_workflow_ref" {
  description = "Exact workflow_ref claim trusted for delivery from main."
  type        = string
  default     = "siamese-lang/application-review-platform/.github/workflows/deploy-release.yml@refs/heads/main"
}

variable "ops_private_ip" {
  description = "Private destination permitted for the GitHub delivery IAP SSH tunnel."
  type        = string
  default     = "10.40.0.50"
}
