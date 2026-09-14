output "edge_public_ip" {
  value = google_compute_address.edge.address
}
output "ops_instance" {
  value = google_compute_instance.node["ops-01"].name
}
output "private_ips" {
  value = { for name, node in google_compute_instance.node : name => node.network_interface[0].network_ip }
}
output "inventory" {
  value = {
    for name, node in local.nodes : name => {
      role       = node.role
      zone       = node.zone
      private_ip = google_compute_instance.node[name].network_interface[0].network_ip
    }
  }
}

output "loadgen" {
  value = var.enable_loadgen ? {
    name       = google_compute_instance.loadgen[0].name
    region     = var.loadgen_region
    zone       = google_compute_instance.loadgen[0].zone
    private_ip = google_compute_instance.loadgen[0].network_interface[0].network_ip
  } : null
}
