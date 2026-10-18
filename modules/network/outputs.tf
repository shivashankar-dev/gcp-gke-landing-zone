output "network_id" {
  description = "Self link ID of the VPC."
  value       = google_compute_network.this.id
}

output "network_name" {
  description = "Name of the VPC."
  value       = google_compute_network.this.name
}

output "subnet_id" {
  description = "ID of the GKE subnet."
  value       = google_compute_subnetwork.gke.id
}

output "pods_range_name" {
  description = "Secondary range name used for pods."
  value       = "pods"
}

output "services_range_name" {
  description = "Secondary range name used for services."
  value       = "services"
}
