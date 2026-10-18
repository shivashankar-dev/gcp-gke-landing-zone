output "cluster_name" {
  description = "GKE cluster name."
  value       = module.gke.cluster_name
}

output "get_credentials" {
  description = "Command to fetch kubeconfig for the cluster."
  value       = "gcloud container clusters get-credentials ${module.gke.cluster_name} --region ${module.gke.cluster_location} --project ${var.project_id}"
}

output "network_name" {
  description = "VPC name."
  value       = module.network.network_name
}
