resource "google_compute_network" "this" {
  project                         = var.project_id
  name                            = "${var.name_prefix}-vpc"
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  delete_default_routes_on_create = false
}

resource "google_compute_subnetwork" "gke" {
  project                  = var.project_id
  name                     = "${var.name_prefix}-gke-${var.region}"
  region                   = var.region
  network                  = google_compute_network.this.id
  ip_cidr_range            = var.subnet_cidr
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Egress for private nodes without public IPs.
resource "google_compute_router" "this" {
  project = var.project_id
  name    = "${var.name_prefix}-router-${var.region}"
  region  = var.region
  network = google_compute_network.this.id
}

resource "google_compute_router_nat" "this" {
  project                            = var.project_id
  name                               = "${var.name_prefix}-nat-${var.region}"
  router                             = google_compute_router.this.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Allow Google health checks and IAP TCP forwarding (SSH without public IPs).
resource "google_compute_firewall" "allow_health_checks" {
  project       = var.project_id
  name          = "${var.name_prefix}-allow-health-checks"
  network       = google_compute_network.this.id
  direction     = "INGRESS"
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]

  allow {
    protocol = "tcp"
  }
}

resource "google_compute_firewall" "allow_iap" {
  project       = var.project_id
  name          = "${var.name_prefix}-allow-iap-ssh"
  network       = google_compute_network.this.id
  direction     = "INGRESS"
  source_ranges = ["35.235.240.0/20"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}
