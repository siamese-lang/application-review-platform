resource "google_compute_instance" "node" {
  for_each     = local.nodes
  name         = each.key
  zone         = each.value.zone
  machine_type = lookup(var.node_machine_type_overrides, each.key, var.machine_types[each.value.role])
  tags         = ["arp-${each.value.role}", "arp-managed"]
  labels       = { milestone = each.key == "obs-01" ? "m7" : "m4", role = each.value.role }

  boot_disk {
    initialize_params {
      image = var.boot_image
      size  = var.boot_disk_size_gb
      type  = lookup(var.node_boot_disk_type_overrides, each.key, each.key == "obs-01" ? "pd-standard" : "pd-balanced")
    }
  }

  dynamic "attached_disk" {
    for_each = (
      each.key == "db-01" ? [google_compute_disk.db.id] :
      each.value.role == "storage" ? [google_compute_disk.garage[each.key].id] :
      each.key == "obs-01" ? [google_compute_disk.observability.id] :
      []
    )
    content {
      source      = attached_disk.value
      device_name = "arp-data"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.m4.id
    network_ip = each.value.ip
    dynamic "access_config" {
      for_each = each.key == "edge-01" ? [1] : []
      content {
        nat_ip = google_compute_address.edge.address
      }
    }
  }

  metadata = {
    enable-oslogin          = "TRUE"
    enable-guest-attributes = "TRUE"
    block-project-ssh-keys  = "TRUE"
  }
  service_account {
    email  = each.value.role == "ops" ? local.ops_service_account_email : local.workload_service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
  allow_stopping_for_update = true
}


resource "google_compute_instance_iam_member" "github_deploy_ops_viewer" {
  project       = var.project_id
  zone          = google_compute_instance.node["ops-01"].zone
  instance_name = google_compute_instance.node["ops-01"].name
  role          = "roles/compute.viewer"
  member        = "serviceAccount:arp-m6-github-deploy@${var.project_id}.iam.gserviceaccount.com"
}

resource "google_compute_instance" "loadgen" {
  count        = var.enable_loadgen ? 1 : 0
  name         = "loadgen-01"
  zone         = var.loadgen_zone
  machine_type = var.loadgen_machine_type
  tags         = ["arp-loadgen", "arp-managed"]
  labels       = { milestone = "m8", role = "loadgen", lifecycle = "temporary" }

  boot_disk {
    initialize_params {
      image = var.boot_image
      size  = var.boot_disk_size_gb
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.loadgen[0].id
    network_ip = var.loadgen_private_ip
  }

  metadata = {
    enable-oslogin          = "TRUE"
    enable-guest-attributes = "TRUE"
    block-project-ssh-keys  = "TRUE"
  }

  allow_stopping_for_update = true
}

resource "google_compute_instance" "backup" {
  count        = var.enable_backup ? 1 : 0
  name         = "backup-01"
  zone         = var.backup_zone
  machine_type = var.backup_machine_type
  tags         = ["arp-backup", "arp-managed"]

  labels = {
    lifecycle = "temporary"
    milestone = "m11"
    role      = "backup"
  }

  boot_disk {
    initialize_params {
      image = var.boot_image
      size  = var.boot_disk_size_gb
      type  = "pd-standard"
    }
  }

  attached_disk {
    source      = google_compute_disk.backup[0].id
    device_name = "arp-backup-data"
  }

  network_interface {
    subnetwork = google_compute_subnetwork.backup[0].id
    network_ip = var.backup_private_ip
  }

  metadata = {
    enable-oslogin          = "TRUE"
    enable-guest-attributes = "TRUE"
    block-project-ssh-keys  = "TRUE"
  }

  allow_stopping_for_update = true
}


resource "google_compute_instance" "recovery_db" {
  count        = var.enable_recovery_db ? 1 : 0
  name         = "recovery-db-01"
  zone         = var.backup_zone
  machine_type = var.recovery_db_machine_type
  tags         = ["arp-recovery-db", "arp-managed"]

  labels = {
    lifecycle = "temporary"
    milestone = "m11"
    role      = "recovery-db"
  }

  boot_disk {
    initialize_params {
      image = var.boot_image
      size  = var.boot_disk_size_gb
      type  = "pd-standard"
    }
  }

  attached_disk {
    source      = google_compute_disk.recovery_db[0].id
    device_name = "arp-recovery-db-data"
  }

  network_interface {
    subnetwork = var.enable_backup ? google_compute_subnetwork.backup[0].id : null
    network_ip = var.recovery_db_private_ip
  }

  metadata = {
    enable-oslogin          = "TRUE"
    enable-guest-attributes = "TRUE"
    block-project-ssh-keys  = "TRUE"
  }

  lifecycle {
    precondition {
      condition     = var.enable_backup
      error_message = "enable_recovery_db=true requires enable_backup=true so the verified M11 backup repository/subnet is available."
    }
  }

  allow_stopping_for_update = true
}

resource "google_compute_instance" "full_dr" {
  for_each     = var.enable_full_dr ? local.full_dr_nodes : {}
  name         = each.key
  zone         = each.value.zone
  machine_type = var.full_dr_machine_types[each.value.role]
  tags         = ["arp-dr-${each.value.role}", "arp-managed"]

  labels = {
    lifecycle = "temporary"
    milestone = "m11"
    role      = "dr-${each.value.role}"
  }

  boot_disk {
    initialize_params {
      image = var.boot_image
      size  = var.boot_disk_size_gb
      type  = "pd-standard"
    }
  }

  dynamic "attached_disk" {
    for_each = (
      each.value.role == "db" ? [google_compute_disk.full_dr_db[0].id] :
      each.value.role == "storage" ? [google_compute_disk.full_dr_storage[each.key].id] :
      []
    )
    content {
      source      = attached_disk.value
      device_name = "arp-data"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.full_dr[0].id
    network_ip = each.value.ip

    dynamic "access_config" {
      for_each = each.value.role == "edge" ? [1] : []
      content {
        nat_ip = google_compute_address.full_dr_edge[0].address
      }
    }
  }

  metadata = {
    enable-oslogin          = "TRUE"
    enable-guest-attributes = "TRUE"
    block-project-ssh-keys  = "TRUE"
  }

  lifecycle {
    precondition {
      condition     = var.enable_backup
      error_message = "enable_full_dr=true requires enable_backup=true so the verified M11 checkpoint repository remains available."
    }
  }

  allow_stopping_for_update = true
}
