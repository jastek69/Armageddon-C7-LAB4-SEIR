resource "aws_route53_zone" "nihonmachi_private_zone" {
  count = var.enable_aws_gcp_tgw_vpn ? 1 : 0

  name = var.ilb_private_zone_name

  vpc {
    vpc_id = aws_vpc.shinjuku_vpc01.id
  }
}

resource "aws_route53_record" "nihonmachi_ilb_private_a" {
  count = local.gcp_ilb_internal_ip_effective != "" ? 1 : 0

  zone_id = aws_route53_zone.nihonmachi_private_zone[0].zone_id
  name    = var.ilb_private_record_name
  type    = "A"
  ttl     = 60
  records = [local.gcp_ilb_internal_ip_effective]
}
