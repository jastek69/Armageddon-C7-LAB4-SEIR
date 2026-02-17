# Explanation: Galactus builds the tunnels; Nihonmachi VPC is the NY clinic’s private street grid.
resource "google_compute_network" "nihonmachi_vpc01" {
  name                    = "nihonmachi-vpc01"
  auto_create_subnetworks = false
}

# Explanation: A private subnet—because medical staff don’t need the public internet to see PHI.
resource "google_compute_subnetwork" "nihonmachi_subnet01" {
  name          = "nihonmachi-subnet01"
  ip_cidr_range = var.nihonmachi_subnet_cidr
  region        = var.gcp_region
  network       = google_compute_network.nihonmachi_vpc01.id
  private_ip_google_access = true
}

# Proxy-only subnet required for internal HTTPS load balancing.
resource "google_compute_subnetwork" "nihonmachi_proxy_only_subnet01" {
  name          = "nihonmachi-proxy-only-subnet01"
  ip_cidr_range = "10.235.254.0/24"
  region        = var.gcp_region
  network       = google_compute_network.nihonmachi_vpc01.id
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}
