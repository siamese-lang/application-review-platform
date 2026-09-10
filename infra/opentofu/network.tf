resource "google_compute_network" "m4" {
  name                    = "arp-m4"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "m4" {
  name                     = "arp-m4-${var.region}"
  region                   = var.region
  network                  = google_compute_network.m4.id
  ip_cidr_range            = var.subnet_cidr
  private_ip_google_access = true
}

resource "google_compute_router" "m4" {
  name    = "arp-m4-router"
  region  = var.region
  network = google_compute_network.m4.id
}

resource "google_compute_router_nat" "m4" {
  name                               = "arp-m4-nat"
  router                             = google_compute_router.m4.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  subnetwork {
    name                    = google_compute_subnetwork.m4.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

resource "google_compute_address" "edge" {
  name   = "arp-edge-01-ipv4"
  region = var.region
}
