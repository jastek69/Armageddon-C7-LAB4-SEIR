resource "tls_private_key" "nihonmachi_ilb" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "nihonmachi_ilb" {
  private_key_pem = tls_private_key.nihonmachi_ilb.private_key_pem

  subject {
    common_name  = var.ilb_cert_common_name
    organization = "Taaops"
  }

  dns_names             = var.ilb_cert_sans
  validity_period_hours = 8760
  allowed_uses          = ["key_encipherment", "digital_signature", "server_auth"]
}
