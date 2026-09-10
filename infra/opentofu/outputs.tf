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
