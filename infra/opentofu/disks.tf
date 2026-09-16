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

resource "google_compute_disk" "observability" {
  name = "arp-obs-01-data"
  zone = local.nodes["obs-01"].zone
  type = "pd-standard"
  size = var.observability_data_disk_size_gb
}

resource "google_compute_disk" "backup" {
  count = var.enable_backup ? 1 : 0
  name  = "arp-backup-01-data"
  zone  = var.backup_zone
  type  = var.backup_data_disk_type
  size  = var.backup_data_disk_size_gb

  labels = {
    lifecycle = "temporary"
    milestone = "m11"
    role      = "backup"
  }
}


resource "google_compute_disk" "recovery_db" {
  count = var.enable_recovery_db ? 1 : 0
  name  = "arp-recovery-db-01-data"
  zone  = var.backup_zone
  type  = "pd-standard"
  size  = var.recovery_db_data_disk_size_gb

  labels = {
    lifecycle = "temporary"
    milestone = "m11"
    role      = "recovery-db"
  }
}

resource "google_compute_disk" "full_dr_db" {
  count = var.enable_full_dr ? 1 : 0
  name  = "arp-dr-db-01-data"
  zone  = local.full_dr_nodes["dr-db-01"].zone
  type  = var.full_dr_data_disk_type
  size  = var.full_dr_db_data_disk_size_gb

  labels = {
    lifecycle = "temporary"
    milestone = "m11"
    role      = "dr-db"
  }
}

resource "google_compute_disk" "full_dr_storage" {
  for_each = var.enable_full_dr ? local.full_dr_storage_nodes : {}
  name     = "arp-${each.key}-data"
  zone     = each.value.zone
  type     = var.full_dr_data_disk_type
  size     = var.full_dr_storage_data_disk_size_gb

  labels = {
    lifecycle = "temporary"
    milestone = "m11"
    role      = "dr-storage"
  }
}
