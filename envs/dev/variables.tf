variable "project_id" {
  description = "GCP project ID for the dev environment."
  type        = string
}

variable "region" {
  description = "GCP region."
  type        = string
  default     = "asia-south1"
}

variable "environment" {
  description = "Environment name, used in resource names and labels."
  type        = string
  default     = "dev"
}

variable "master_authorized_networks" {
  description = "CIDRs allowed to reach the GKE control plane, e.g. your office or VPN egress IP."
  type = list(object({
    cidr = string
    name = string
  }))
  default = []
}
