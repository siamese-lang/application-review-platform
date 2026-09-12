output "ops_service_account_email" {
  value = google_service_account.ops.email
}

output "workload_service_account_email" {
  value = google_service_account.workload.email
}

output "github_workload_identity_provider" {
  description = "Full provider resource name for the future GCP_WORKLOAD_IDENTITY_PROVIDER repository variable."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "github_deployment_service_account_email" {
  description = "Dedicated identity email for the future GCP_DEPLOY_SERVICE_ACCOUNT repository variable."
  value       = google_service_account.github_deploy.email
}

output "github_workload_identity_pool_name" {
  description = "Full Workload Identity Pool resource name for operator inspection."
  value       = google_iam_workload_identity_pool.github.name
}
