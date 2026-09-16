resource "google_compute_firewall" "edge_https" {
  name          = "arp-edge-https"
  network       = google_compute_network.m4.name
  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["arp-edge"]
  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
}

resource "google_compute_firewall" "edge_http" {
  count         = var.enable_http ? 1 : 0
  name          = "arp-edge-http-acme-redirect"
  network       = google_compute_network.m4.name
  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["arp-edge"]
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
}

resource "google_compute_firewall" "edge_app" {
  name        = "arp-edge-to-app"
  network     = google_compute_network.m4.name
  direction   = "INGRESS"
  source_tags = ["arp-edge"]
  target_tags = ["arp-app"]
  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }
}

resource "google_compute_firewall" "observability_app_probe" {
  name        = "arp-observability-to-app-probe"
  network     = google_compute_network.m4.name
  direction   = "INGRESS"
  source_tags = ["arp-observability"]
  target_tags = ["arp-app"]
  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }
}

resource "google_compute_firewall" "app_db" {
  name        = "arp-app-to-db"
  network     = google_compute_network.m4.name
  direction   = "INGRESS"
  source_tags = ["arp-app"]
  target_tags = ["arp-db"]
  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }
}

resource "google_compute_firewall" "app_garage" {
  name        = "arp-app-to-garage-s3"
  network     = google_compute_network.m4.name
  direction   = "INGRESS"
  source_tags = ["arp-app"]
  target_tags = ["arp-storage"]
  allow {
    protocol = "tcp"
    ports    = ["3900"]
  }
}

resource "google_compute_firewall" "garage_rpc" {
  name        = "arp-garage-rpc"
  network     = google_compute_network.m4.name
  direction   = "INGRESS"
  source_tags = ["arp-storage"]
  target_tags = ["arp-storage"]
  allow {
    protocol = "tcp"
    ports    = ["3901"]
  }
}

resource "google_compute_firewall" "telemetry_observability" {
  name        = "arp-telemetry-to-observability"
  network     = google_compute_network.m4.name
  direction   = "INGRESS"
  source_tags = ["arp-edge", "arp-app", "arp-db", "arp-storage"]
  target_tags = ["arp-observability"]
  allow {
    protocol = "tcp"
    ports    = ["9090", "3100", "4317", "4318"]
  }
}

resource "google_compute_firewall" "ops_grafana" {
  name        = "arp-ops-to-grafana"
  network     = google_compute_network.m4.name
  direction   = "INGRESS"
  source_tags = ["arp-ops"]
  target_tags = ["arp-observability"]
  allow {
    protocol = "tcp"
    ports    = ["3000"]
  }
}

resource "google_compute_firewall" "ops_ssh" {
  name        = "arp-ops-to-managed-ssh"
  network     = google_compute_network.m4.name
  direction   = "INGRESS"
  source_tags = ["arp-ops"]
  target_tags = ["arp-managed"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "iap_ssh" {
  name          = "arp-iap-ssh"
  network       = google_compute_network.m4.name
  direction     = "INGRESS"
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["arp-ops"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "db_backup_ssh" {
  count       = var.enable_backup ? 1 : 0
  name        = "arp-db-to-backup-pgbackrest"
  network     = google_compute_network.m4.name
  direction   = "INGRESS"
  source_tags = ["arp-db"]
  target_tags = ["arp-backup"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "backup_db_ssh" {
  count       = var.enable_backup ? 1 : 0
  name        = "arp-backup-to-db-pgbackrest"
  network     = google_compute_network.m4.name
  direction   = "INGRESS"
  source_tags = ["arp-backup"]
  target_tags = ["arp-db"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "backup_garage_s3" {
  count       = var.enable_backup ? 1 : 0
  name        = "arp-backup-to-garage-s3"
  network     = google_compute_network.m4.name
  direction   = "INGRESS"
  source_tags = ["arp-backup"]
  target_tags = ["arp-storage"]

  allow {
    protocol = "tcp"
    ports    = ["3900"]
  }
}


resource "google_compute_firewall" "backup_recovery_db_ssh" {
  count       = var.enable_recovery_db ? 1 : 0
  name        = "arp-backup-to-recovery-db-pgbackrest"
  network     = google_compute_network.m4.name
  direction   = "INGRESS"
  source_tags = ["arp-backup"]
  target_tags = ["arp-recovery-db"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "recovery_db_backup_ssh" {
  count       = var.enable_recovery_db ? 1 : 0
  name        = "arp-recovery-db-to-backup-pgbackrest"
  network     = google_compute_network.m4.name
  direction   = "INGRESS"
  source_tags = ["arp-recovery-db"]
  target_tags = ["arp-backup"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "full_dr_edge_https" {
  count         = var.enable_full_dr ? 1 : 0
  name          = "arp-m11-dr-edge-https"
  network       = google_compute_network.m4.name
  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["arp-dr-edge"]

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
}

resource "google_compute_firewall" "full_dr_edge_http" {
  count         = var.enable_full_dr && var.enable_http ? 1 : 0
  name          = "arp-m11-dr-edge-http"
  network       = google_compute_network.m4.name
  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["arp-dr-edge"]

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
}

resource "google_compute_firewall" "full_dr_edge_app" {
  count       = var.enable_full_dr ? 1 : 0
  name        = "arp-m11-dr-edge-to-app"
  network     = google_compute_network.m4.name
  direction   = "INGRESS"
  source_tags = ["arp-dr-edge"]
  target_tags = ["arp-dr-app"]

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }
}

resource "google_compute_firewall" "full_dr_app_db" {
  count       = var.enable_full_dr ? 1 : 0
  name        = "arp-m11-dr-app-to-db"
  network     = google_compute_network.m4.name
  direction   = "INGRESS"
  source_tags = ["arp-dr-app"]
  target_tags = ["arp-dr-db"]

  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }
}

resource "google_compute_firewall" "full_dr_app_garage" {
  count       = var.enable_full_dr ? 1 : 0
  name        = "arp-m11-dr-app-to-garage"
  network     = google_compute_network.m4.name
  direction   = "INGRESS"
  source_tags = ["arp-dr-app"]
  target_tags = ["arp-dr-storage"]

  allow {
    protocol = "tcp"
    ports    = ["3900"]
  }
}

resource "google_compute_firewall" "full_dr_garage_rpc" {
  count       = var.enable_full_dr ? 1 : 0
  name        = "arp-m11-dr-garage-rpc"
  network     = google_compute_network.m4.name
  direction   = "INGRESS"
  source_tags = ["arp-dr-storage"]
  target_tags = ["arp-dr-storage"]

  allow {
    protocol = "tcp"
    ports    = ["3901"]
  }
}

resource "google_compute_firewall" "backup_full_dr_db_ssh" {
  count       = var.enable_full_dr && var.enable_backup ? 1 : 0
  name        = "arp-m11-backup-to-dr-db"
  network     = google_compute_network.m4.name
  direction   = "INGRESS"
  source_tags = ["arp-backup"]
  target_tags = ["arp-dr-db"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "full_dr_db_backup_ssh" {
  count       = var.enable_full_dr && var.enable_backup ? 1 : 0
  name        = "arp-m11-dr-db-to-backup"
  network     = google_compute_network.m4.name
  direction   = "INGRESS"
  source_tags = ["arp-dr-db"]
  target_tags = ["arp-backup"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "backup_full_dr_garage_s3" {
  count       = var.enable_full_dr && var.enable_backup ? 1 : 0
  name        = "arp-m11-backup-to-dr-garage"
  network     = google_compute_network.m4.name
  direction   = "INGRESS"
  source_tags = ["arp-backup"]
  target_tags = ["arp-dr-storage"]

  allow {
    protocol = "tcp"
    ports    = ["3900"]
  }
}
