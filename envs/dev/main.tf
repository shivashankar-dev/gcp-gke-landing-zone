terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0, < 7.0"
    }
  }

  # Partial config: the bucket is passed at init time
  # (terraform init -backend-config="bucket=<your-state-bucket>").
  backend "gcs" {
    prefix = "gke-landing-zone/dev"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  name_prefix = "lz-${var.environment}"
  labels = {
    environment = var.environment
    managed-by  = "terraform"
    stack       = "gke-landing-zone"
  }
}

resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "artifactregistry.googleapis.com",
    "binaryauthorization.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

module "network" {
  source = "../../modules/network"

  project_id    = var.project_id
  region        = var.region
  name_prefix   = local.name_prefix
  subnet_cidr   = "10.10.0.0/20"
  pods_cidr     = "10.20.0.0/16"
  services_cidr = "10.30.0.0/20"

  depends_on = [google_project_service.apis]
}

module "gke" {
  source = "../../modules/gke"

  project_id          = var.project_id
  region              = var.region
  name_prefix         = local.name_prefix
  network_id          = module.network.network_id
  subnet_id           = module.network.subnet_id
  pods_range_name     = module.network.pods_range_name
  services_range_name = module.network.services_range_name

  master_authorized_networks = var.master_authorized_networks
  machine_type               = "e2-standard-2"
  min_nodes_per_zone         = 1
  max_nodes_per_zone         = 2
  deletion_protection        = false # dev sandbox only
  labels                     = local.labels
}
