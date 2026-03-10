############################################
# Break-glass CloudFront cache invalidation (run on demand)
#
# NOTE: The aws_cloudfront_create_invalidation action block schema in provider 6.x
# does not use distribution_id/invalidation_batch HCL arguments — using
# terraform_data + local-exec (aws CLI) instead, which is stable and equivalent.
#
# Usage — Terraform (gated, off by default):
#   cd global
#   terraform apply -var="break_glass_invalidation=true"
#   terraform apply -var="break_glass_invalidation=true" \
#     -var='break_glass_paths=["/images/*","/index.html"]'
#
# Usage — CLI (fastest, no Terraform state needed):
#   bash ../scripts/order66.sh
#   bash ../scripts/order66.sh "/images/*" "/index.html"
############################################

resource "terraform_data" "break_glass_invalidation" {
  count = var.break_glass_invalidation ? 1 : 0

  triggers_replace = {
    distribution_id = aws_cloudfront_distribution.galactus_cf01.id
    paths           = jsonencode(var.break_glass_paths)
    caller_ref      = timestamp()
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-lc"]
    command     = <<-EOT
      aws cloudfront create-invalidation \
        --distribution-id "${aws_cloudfront_distribution.galactus_cf01.id}" \
        --region us-east-1 \
        --invalidation-batch "{
          \"Paths\": {
            \"Quantity\": ${length(var.break_glass_paths)},
            \"Items\": ${jsonencode(var.break_glass_paths)}
          },
          \"CallerReference\": \"tf-break-glass-$(date +%s)\"
        }" \
        --query "Invalidation.{Id:Id,Status:Status}" \
        --output table
    EOT
  }
}
