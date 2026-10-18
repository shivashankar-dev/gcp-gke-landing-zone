variable "project_id" {
  description = "GCP project that hosts the cluster."
  type        = string
}

variable "region" {
  description = "Region for the regional cluster (nodes spread across its zones)."
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "network_id" {
  description = "VPC ID from the network module."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID from the network module."
  type        = string
}

variable "pods_range_name" {
  description = "Secondary range name for pods."
  type        = string
}

variable "services_range_name" {
  description = "Secondary range name for services."
  type        = string
}

variable "master_cidr" {
  description = "/28 range for the control plane's private endpoint."
  type        = string
  default     = "172.16.0.0/28"
}

variable "private_endpoint" {
  description = "If true, the control plane has no public endpoint (reach it through a bastion or VPN)."
  type        = bool
  default     = false
}

variable "master_authorized_networks" {
  description = "CIDRs allowed to reach the control plane."
  type = list(object({
    cidr = string
    name = string
  }))
  default = []
}

variable "release_channel" {
  description = "GKE release channel: RAPID, REGULAR or STABLE."
  type        = string
  default     = "REGULAR"

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE"], var.release_channel)
    error_message = "release_channel must be RAPID, REGULAR or STABLE."
  }
}

variable "machine_type" {
  description = "Machine type for the general node pool."
  type        = string
  default     = "e2-standard-4"
}

variable "min_nodes_per_zone" {
  description = "Autoscaler minimum per zone."
  type        = number
  default     = 1
}

variable "max_nodes_per_zone" {
  description = "Autoscaler maximum per zone."
  type        = number
  default     = 3
}

variable "deletion_protection" {
  description = "Block terraform destroy on the cluster. Keep true outside sandboxes."
  type        = bool
  default     = true
}

variable "rbac_security_group" {
  description = "Optional Google Group for RBAC, must be gke-security-groups@<your-domain>. Null disables it."
  type        = string
  default     = null
}

variable "labels" {
  description = "Labels applied to the cluster and nodes."
  type        = map(string)
  default     = {}
}
