resource "google_service_account" "workload" {
  account_id   = "arp-m4-workload"
  display_name = "ARP M4 unprivileged workload identity"
}

resource "google_service_account" "ops" {
  account_id   = "arp-m4-ops"
  display_name = "ARP M4 operations identity"
}

resource "google_service_account" "github_deploy" {
  account_id   = "arp-m6-github-deploy"
  display_name = "ARP M6 GitHub delivery identity"
  description  = "Keyless GitHub delivery access to ops-01 only; not an infrastructure administration identity."
}

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "arp-m6-github"
  display_name              = "ARP M6 GitHub Actions"
  description               = "Keyless identity pool for the exact ARP release deployment workflow."
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "arp-m6-deploy"
  display_name                       = "ARP M6 release deployment"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"          = "assertion.repository"
    "attribute.repository_id"       = "assertion.repository_id"
    "attribute.repository_owner"    = "assertion.repository_owner"
    "attribute.repository_owner_id" = "assertion.repository_owner_id"
    "attribute.ref"                 = "assertion.ref"
    "attribute.workflow_ref"     = "assertion.workflow_ref"
    "attribute.event_name"       = "assertion.event_name"
  }

  attribute_condition = <<-EOT
    assertion.repository == '${var.github_repository}' &&
    assertion.repository_id == '${var.github_repository_id}' &&
    assertion.repository_owner == '${var.github_repository_owner}' &&
    assertion.repository_owner_id == '${var.github_repository_owner_id}' &&
    assertion.ref == 'refs/heads/main' &&
    assertion.workflow_ref == '${var.github_deployment_workflow_ref}' &&
    assertion.event_name == 'workflow_dispatch'
  EOT

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "github_deploy_wif" {
  service_account_id = google_service_account.github_deploy.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository_id/${var.github_repository_id}"
}

resource "google_project_iam_member" "github_deploy_oslogin" {
  project = var.project_id
  role    = "roles/compute.osAdminLogin"
  member  = "serviceAccount:${google_service_account.github_deploy.email}"
}

resource "google_project_iam_member" "github_deploy_iap_ssh" {
  project = var.project_id
  role    = "roles/iap.tunnelResourceAccessor"
  member  = "serviceAccount:${google_service_account.github_deploy.email}"

  condition {
    title       = "ops-01-ssh-only"
    description = "Permit IAP TCP forwarding only to the ops-01 private SSH endpoint."
    expression  = "destination.ip == '${var.ops_private_ip}' && destination.port == 22"
  }
}

resource "google_service_account_iam_member" "github_deploy_ops_act_as" {
  service_account_id = google_service_account.ops.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.github_deploy.email}"
}

resource "google_project_iam_member" "ops_roles" {
  for_each = toset([
    "roles/compute.admin",
    "roles/compute.networkAdmin",
    "roles/compute.osAdminLogin",
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.ops.email}"
}

resource "google_project_iam_member" "admin_oslogin" {
  for_each = var.admin_oslogin_members
  project  = var.project_id
  role     = "roles/compute.osAdminLogin"
  member   = each.value
}

resource "google_project_iam_member" "admin_iap" {
  for_each = var.admin_oslogin_members
  project  = var.project_id
  role     = "roles/iap.tunnelResourceAccessor"
  member   = each.value
}

locals {
  service_account_users = setunion(
    var.admin_oslogin_members,
    toset(["serviceAccount:${google_service_account.ops.email}"])
  )
}

resource "google_service_account_iam_member" "workload_act_as" {
  for_each           = local.service_account_users
  service_account_id = google_service_account.workload.name
  role               = "roles/iam.serviceAccountUser"
  member             = each.value
}

resource "google_service_account_iam_member" "ops_act_as" {
  for_each           = local.service_account_users
  service_account_id = google_service_account.ops.name
  role               = "roles/iam.serviceAccountUser"
  member             = each.value
}
