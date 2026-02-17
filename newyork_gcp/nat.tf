# Explanation: Chewbacca dislikes public IPs; Cloud NAT lets VMs update safely without exposing services.
resource "google_compute_router" "nihonmachi_router01" {
  name    = "nihonmachi-router01"
  region  = var.gcp_region
  network = google_compute_network.nihonmachi_vpc01.id
}

resource "google_compute_router_nat" "nihonmachi_nat01" {
  name                               = "nihonmachi-nat01"
  router                             = google_compute_router.nihonmachi_router01.name
  region                             = var.gcp_region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}