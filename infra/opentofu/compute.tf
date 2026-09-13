resource "google_compute_instance" "node" {
  for_each     = local.nodes
  name         = each.key
  zone         = each.value.zone
  machine_type = lookup(var.node_machine_type_overrides, each.key, var.machine_types[each.value.role])
  tags         = concat(["arp-${each.value.role}", "arp-managed"], each.key == "storage-01" ? ["arp-garage-endpoint"] : [])
  labels       = { milestone = each.key == "obs-01" ? "m7" : "m4", role = each.value.role }

  boot_disk {
    initialize_params {
      image = var.boot_image
      size  = var.boot_disk_size_gb
      type  = lookup(var.node_boot_disk_type_overrides, each.key, "pd-balanced")
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
