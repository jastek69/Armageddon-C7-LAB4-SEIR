data "terraform_remote_state" "tokyo" {
  backend = "s3"
  config = {
    bucket = var.tokyo_state_bucket
    key    = var.tokyo_state_key
    region = var.tokyo_state_region
  }
}
