resource "google_service_account" "workload" {
  account_id   = "arp-m4-workload"
  display_name = "ARP M4 unprivileged workload identity"
}

resource "google_service_account" "ops" {
  account_id   = "arp-m4-ops"
  display_name = "ARP M4 operations identity"
}

resource "google_project_iam_member" "ops_roles" {
  for_each = toset([
    "roles/compute.admin",
    "roles/compute.networkAdmin",
    "roles/iam.serviceAccountUser",
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
