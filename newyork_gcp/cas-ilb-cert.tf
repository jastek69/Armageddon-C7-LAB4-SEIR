resource "google_privateca_ca_pool" "nihonmachi_ca_pool" {
  provider = google-beta

  name     = var.cas_pool_id
  location = var.cas_location
  tier     = "DEVOPS"
}

resource "google_privateca_certificate_authority" "nihonmachi_ca" {
  provider = google-beta

  certificate_authority_id = var.cas_ca_id
  location                 = var.cas_location
  pool                     = google_privateca_ca_pool.nihonmachi_ca_pool.name
  type                     = "SELF_SIGNED"

  config {
    subject_config {
      subject {
        common_name  = "nihonmachi-root-ca"
        organization = "Taaops"
      }
    }

    x509_config {
      ca_options {
        is_ca = true
      }
      key_usage {
        base_key_usage {
          cert_sign = true
          crl_sign  = true
        }
      }
    }
  }

  key_spec {
    algorithm = "RSA_PKCS1_2048_SHA256"
  }
}

resource "tls_private_key" "nihonmachi_ilb" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "nihonmachi_ilb" {
  private_key_pem = tls_private_key.nihonmachi_ilb.private_key_pem

  subject {
    common_name  = var.ilb_cert_common_name
    organization = "Taaops"
  }

  dns_names = var.ilb_cert_sans
}

resource "google_privateca_certificate" "nihonmachi_ilb_cert" {
  provider = google-beta

  location                 = var.cas_location
  pool                     = google_privateca_ca_pool.nihonmachi_ca_pool.name
  certificate_authority    = google_privateca_certificate_authority.nihonmachi_ca.name
  pem_csr                  = tls_cert_request.nihonmachi_ilb.cert_request_pem
  lifetime                 = "31536000s"
}
