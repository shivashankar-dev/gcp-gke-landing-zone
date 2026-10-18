output "cluster_name" {
  description = "Name of the GKE cluster."
  value       = google_container_cluster.this.name
}

output "cluster_location" {
  description = "Region of the cluster."
  value       = google_container_cluster.this.location
}

output "node_service_account" {
  description = "Email of the node service account."
  value       = google_service_account.nodes.email
}

output "workload_pool" {
  description = "Workload Identity pool for binding Kubernetes service accounts to Google service accounts."
  value       = "${var.project_id}.svc.id.goog"
}
