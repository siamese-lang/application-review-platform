locals {
  nodes = {
    edge-01    = { role = "edge", zone = "${var.region}-a", ip = "10.40.0.10" }
    app-01     = { role = "app", zone = "${var.region}-a", ip = "10.40.0.20" }
    db-01      = { role = "db", zone = "${var.region}-a", ip = "10.40.0.30" }
    storage-01 = { role = "storage", zone = "${var.region}-a", ip = "10.40.0.41" }
    storage-02 = { role = "storage", zone = "${var.region}-b", ip = "10.40.0.42" }
    storage-03 = { role = "storage", zone = "${var.region}-c", ip = "10.40.0.43" }
    ops-01     = { role = "ops", zone = "${var.region}-a", ip = "10.40.0.50" }
  }
  storage_nodes                   = { for name, node in local.nodes : name => node if node.role == "storage" }
  ops_service_account_email       = "arp-m4-ops@${var.project_id}.iam.gserviceaccount.com"
  workload_service_account_email  = "arp-m4-workload@${var.project_id}.iam.gserviceaccount.com"
}
