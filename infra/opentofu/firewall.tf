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
