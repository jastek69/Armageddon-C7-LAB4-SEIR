# Explanation: Chewbacca guards the clinic door—HTTPS is allowed ONLY from inside the corridor.
resource "google_compute_firewall" "nihonmachi_allow_https_from_vpn01" {
  name    = "nihonmachi-allow-https-from-vpn01"
  network = google_compute_network.nihonmachi_vpc01.name

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = var.allowed_vpn_cidrs
  target_tags   = ["nihonmachi-app"]
}

# Explanation: Allow internal health checks (ILB) to reach instances.
resource "google_compute_firewall" "nihonmachi_allow_hc01" {
  name    = "nihonmachi-allow-hc01"
  network = google_compute_network.nihonmachi_vpc01.name

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  # GCP health check ranges (students can keep this as-is; instructor can provide exact ranges later if desired)
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["nihonmachi-app"]
}

# Allow proxy-only subnet to reach the backends for internal HTTPS LB data plane.
resource "google_compute_firewall" "nihonmachi_allow_ilb_proxy01" {
  name    = "nihonmachi-allow-ilb-proxy01"
  network = google_compute_network.nihonmachi_vpc01.name

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = ["10.235.254.0/24"]
  target_tags   = ["nihonmachi-app"]
}

# Allow IAP SSH access for managed instances.
resource "google_compute_firewall" "allow_iap_ssh_vpc01" {
  name    = "allow-iap-ssh-vpc01"
  network = google_compute_network.nihonmachi_vpc01.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # IAP TCP forwarding range.
  source_ranges = ["35.235.240.0/20"]
}

# Allow general VPN traffic (Ike/Ipsec) for AWS tunnels.
resource "google_compute_firewall" "allow_vpn_traffic" {
  name    = "allow-vpn-traffic"
  network = google_compute_network.nihonmachi_vpc01.name

  allow {
    protocol = "udp"
    ports    = ["500", "4500"]
  }

  allow {
    protocol = "esp"
  }

  source_ranges = ["0.0.0.0/0"]
}