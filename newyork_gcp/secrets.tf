# Explanation: Galactus keeps the DB password in GCP Secret Manager so it never
# touches Terraform state or environment logs on the instances.
# The startup script fetches it at boot via: gcloud secrets versions access latest

resource "google_project_service" "secretmanager_api" {
  project            = var.gcp_project_id
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_secret_manager_secret" "nihonmachi_db_password" {
  depends_on = [google_project_service.secretmanager_api]
  secret_id = var.db_password_secret_name
  project   = var.gcp_project_id

  replication {
    auto {}
  }

  labels = {
    env     = "lab4"
    purpose = "tokyo-rds-password"
  }
}

# Initial version — set once; rotation updates it outside Terraform.
# ignore_changes prevents Terraform from overwriting a rotated password on re-apply.
resource "google_secret_manager_secret_version" "nihonmachi_db_password_v1" {
  secret      = google_secret_manager_secret.nihonmachi_db_password.id
  secret_data = var.db_password

  lifecycle {
    ignore_changes = [secret_data]
  }
}

# Grant the Nihonmachi instance service account read access to this secret.
resource "google_secret_manager_secret_iam_member" "nihonmachi_sa_secret_accessor" {
  secret_id = google_secret_manager_secret.nihonmachi_db_password.secret_id
  project   = var.gcp_project_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.nihonmachi_service_account_email}"
}
