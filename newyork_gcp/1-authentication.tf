provider "aws" {
  region  = "ap-northeast-1"                 # Choose your region
  profile = "default"
}

provider "awscc" {
  region  = "ap-northeast-1"              # Choose your region
  profile = "default"
}

provider "google" {
  credentials = file(var.gcp_credentials)    # GCP credentials from variable
  project     = var.project_id
  region      = var.region
  zone        = var.zone
}

provider "google-beta" {
  credentials = file(var.gcp_credentials)
  project     = var.project_id
  region      = var.region
  zone        = var.zone
}

provider "time" {}
