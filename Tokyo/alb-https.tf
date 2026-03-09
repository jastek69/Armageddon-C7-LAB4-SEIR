locals {
  alb_origin_fqdn = "${var.alb_origin_subdomain}.${var.domain_name}"

  alb_origin_cert_arn = var.alb_origin_cert_arn != "" ? var.alb_origin_cert_arn : (
    length(aws_acm_certificate.tokyo_alb_origin) > 0 ? aws_acm_certificate.tokyo_alb_origin[0].arn : ""
  )

  alb_origin_dvo = var.alb_origin_cert_arn == "" ? tolist(aws_acm_certificate.tokyo_alb_origin[0].domain_validation_options) : []
}

resource "aws_acm_certificate" "tokyo_alb_origin" {
  count             = var.alb_origin_cert_arn == "" ? 1 : 0
  domain_name       = local.alb_origin_fqdn
  validation_method = var.certificate_validation_method
}

resource "aws_route53_record" "tokyo_alb_origin_cert_validation" {
  count           = var.alb_origin_cert_arn == "" ? 1 : 0
  allow_overwrite = true

  zone_id = data.aws_route53_zone.main-taaops.zone_id
  name    = local.alb_origin_dvo[0].resource_record_name
  type    = local.alb_origin_dvo[0].resource_record_type
  records = [local.alb_origin_dvo[0].resource_record_value]
  ttl     = 300
}

resource "aws_acm_certificate_validation" "tokyo_alb_origin" {
  count                   = var.alb_origin_cert_arn == "" ? 1 : 0
  certificate_arn         = aws_acm_certificate.tokyo_alb_origin[0].arn
  validation_record_fqdns = [aws_route53_record.tokyo_alb_origin_cert_validation[0].fqdn]
}

resource "aws_lb_listener" "tokyo_alb_https_listener" {
  load_balancer_arn = aws_lb.tokyo_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = local.alb_origin_cert_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tokyo_tg80.arn
  }

  depends_on = [aws_acm_certificate_validation.tokyo_alb_origin]
}
