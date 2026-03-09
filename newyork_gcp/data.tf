data "terraform_remote_state" "tokyo" {
  count   = var.enable_aws_gcp_tgw_vpn ? 1 : 0
  backend = "s3"
  config = {
    bucket = var.tokyo_state_bucket
    key    = var.tokyo_state_key
    region = var.tokyo_state_region
  }
  # Defaults allow terraform plan to succeed before Tokyo state exists.
  # Empty strings are replaced by real VPN tunnel IPs once Tokyo has been applied.
  defaults = {
    gcp_tgw_vpn1_tunnel1_address = ""
    gcp_tgw_vpn1_tunnel2_address = ""
    gcp_tgw_vpn2_tunnel1_address = ""
    gcp_tgw_vpn2_tunnel2_address = ""
  }
}
