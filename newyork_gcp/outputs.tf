output "gcp_ha_vpn_interface_0_ip" {
  value       = google_compute_ha_vpn_gateway.gcp-to-aws-vpn-gw.vpn_interfaces[0].ip_address
  description = "GCP HA VPN interface 0 public IP"
}

output "gcp_ha_vpn_interface_1_ip" {
  value       = google_compute_ha_vpn_gateway.gcp-to-aws-vpn-gw.vpn_interfaces[1].ip_address
  description = "GCP HA VPN interface 1 public IP"
}

output "nihonmachi_ilb_ip" {
  value       = google_compute_forwarding_rule.nihonmachi_fr01.ip_address
  description = "Internal HTTPS load balancer IP for Nihonmachi"
}
