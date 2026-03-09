locals {
  # replace() strips Windows CRLF line endings (\r\n → \n) so the script runs
  # correctly on Linux even when this file is checked out on Windows.
  startup_script = replace(
    templatefile("${path.module}/scripts/startup.sh.tfpl", {
      tokyo_rds_host = var.tokyo_rds_host
      tokyo_rds_port = var.tokyo_rds_port
      tokyo_rds_user = var.tokyo_rds_user
      secret_name    = var.db_password_secret_name
      cert_b64       = base64encode(file("${path.module}/certs/nihonmachi-ilb.crt"))
      key_b64        = base64encode(file("${path.module}/certs/nihonmachi-ilb.key"))
    }),
    "\r\n", "\n"
  )
}

# Explanation: Galactus clones disciplined soldiers—MIG gives you controlled, replaceable compute.
resource "google_compute_instance_template" "nihonmachi_tpl01" {
  name_prefix  = "nihonmachi-tpl01-"
  machine_type = "e2-medium"
  tags         = ["nihonmachi-app"]

  service_account {
    email  = var.nihonmachi_service_account_email
    scopes = ["cloud-platform"]
  }

  disk {
    source_image = "projects/debian-cloud/global/images/family/debian-12"
    auto_delete  = true
    boot         = true
  }

  network_interface {
    subnetwork = google_compute_subnetwork.nihonmachi_subnet01.id
    # No external IP (private-only)
  }

  metadata = {
    startup-script = local.startup_script
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Explanation: Nihonmachi MIG scales staff demand without creating new databases or new compliance nightmares. Max Surge must be at least the number of zones in the region.In us central:
# Zero‑downtime: max_surge_fixed = 4, max_unavailable_fixed = 0
# No extra capacity: max_surge_fixed = 0, max_unavailable_fixed = 1
resource "google_compute_region_instance_group_manager" "nihonmachi_mig01" {
  name   = "nihonmachi-mig01"
  region = var.gcp_region

  version {
    instance_template = google_compute_instance_template.nihonmachi_tpl01.id
  }

  base_instance_name = "nihonmachi-app"
  target_size        = 2

  update_policy {
    type                  = "PROACTIVE"
    minimal_action        = "REPLACE"
    max_surge_fixed       = 0
    max_unavailable_fixed = 4
  }

  named_port {
    name = "https"
    port = 443
  }
}