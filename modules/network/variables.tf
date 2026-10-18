variable "project_id" {
  description = "GCP project that hosts the network."
  type        = string
}

variable "region" {
  description = "Region for the subnet, router and NAT."
  type        = string
}

variable "name_prefix" {
  description = "Prefix for every resource name, e.g. \"lz-dev\"."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.name_prefix))
    error_message = "name_prefix must be lowercase letters, digits or hyphens, 2-21 characters, starting with a letter."
  }
}

variable "subnet_cidr" {
  description = "Primary range for GKE nodes."
  type        = string
}

variable "pods_cidr" {
  description = "Secondary range for pods."
  type        = string
}

variable "services_cidr" {
  description = "Secondary range for services."
  type        = string
}
