output "ops_service_account_email" {
  value = google_service_account.ops.email
}

output "workload_service_account_email" {
  value = google_service_account.workload.email
}
