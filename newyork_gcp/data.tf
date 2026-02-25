data "terraform_remote_state" "tokyo" {
  count   = var.enable_aws_gcp_tgw_vpn ? 1 : 0
  backend = "s3"
  config = {
    bucket = var.tokyo_state_bucket
    key    = var.tokyo_state_key
    region = var.tokyo_state_region
  }
}
