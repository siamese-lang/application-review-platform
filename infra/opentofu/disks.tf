resource "google_compute_disk" "db" {
  name = "arp-db-01-data"
  zone = local.nodes["db-01"].zone
  type = "pd-balanced"
  size = var.db_data_disk_size_gb
}

resource "google_compute_disk" "garage" {
  for_each = local.storage_nodes
  name     = "arp-${each.key}-data"
  zone     = each.value.zone
  type     = "pd-balanced"
  size     = var.garage_data_disk_size_gb
}
