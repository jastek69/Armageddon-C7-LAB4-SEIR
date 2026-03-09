data "aws_caller_identity" "current" {}

data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

data "terraform_remote_state" "tokyo" {
  backend = "s3"
  config = {
    bucket = var.tokyo_state_bucket
    key    = var.tokyo_state_key
    region = var.tokyo_state_region
  }
  # Defaults allow terraform plan to succeed before Tokyo state exists.
  # Empty strings are replaced by real values once Tokyo has been applied.
  defaults = {
    tokyo_alb_sg_id              = ""
    tokyo_alb_https_listener_arn = ""
    tokyo_alb_tg_arn             = ""
    tokyo_alb_dns_name           = ""
    tokyo_alb_zone_id            = ""
  }
}
