# Dedicated, least-privilege service account for nodes (never the default compute SA).
resource "google_service_account" "nodes" {
  project      = var.project_id
  account_id   = "${var.name_prefix}-gke-nodes"
  display_name = "GKE nodes for ${var.name_prefix}"
}

resource "google_project_iam_member" "nodes" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/artifactregistry.reader",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.nodes.email}"
}

resource "google_container_cluster" "this" {
  # checkov:skip=CKV_GCP_12:Dataplane V2 (ADVANCED_DATAPATH) enforces NetworkPolicy natively
  # checkov:skip=CKV_GCP_69:GKE metadata server is set on the managed node pool; the default pool is removed
  # checkov:skip=CKV_GCP_65:Google Groups for RBAC needs a Workspace domain; set var.rbac_security_group to enable
  project  = var.project_id
  name     = "${var.name_prefix}-gke"
  location = var.region

  network    = var.network_id
  subnetwork = var.subnet_id

  # Node pools are managed separately so they can change without recreating the cluster.
  remove_default_node_pool = true
  initial_node_count       = 1

  deletion_protection         = var.deletion_protection
  datapath_provider           = "ADVANCED_DATAPATH" # Dataplane V2: eBPF networking + built-in network policy
  enable_intranode_visibility = true

  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  dynamic "authenticator_groups_config" {
    for_each = var.rbac_security_group == null ? [] : [var.rbac_security_group]
    content {
      security_group = authenticator_groups_config.value
    }
  }

  release_channel {
    channel = var.release_channel
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = var.private_endpoint
    master_ipv4_cidr_block  = var.master_cidr
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.master_authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr
        display_name = cidr_blocks.value.name
      }
    }
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  security_posture_config {
    mode               = "BASIC"
    vulnerability_mode = "VULNERABILITY_BASIC"
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = true
    }
  }

  maintenance_policy {
    recurring_window {
      start_time = "2026-01-03T20:00:00Z"
      end_time   = "2026-01-04T02:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=SA"
    }
  }

  resource_labels = var.labels
}

resource "google_container_node_pool" "general" {
  project  = var.project_id
  name     = "general"
  location = var.region
  cluster  = google_container_cluster.this.name

  autoscaling {
    min_node_count = var.min_nodes_per_zone
    max_node_count = var.max_nodes_per_zone
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  node_config {
    machine_type    = var.machine_type
    disk_type       = "pd-balanced"
    disk_size_gb    = 50
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    labels          = var.labels

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  depends_on = [google_project_iam_member.nodes]
}
