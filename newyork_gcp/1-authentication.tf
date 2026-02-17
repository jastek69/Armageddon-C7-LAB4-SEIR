provider "aws" {
  region  = "ap-northeast-1"                 # Choose your region
  profile = "default"
}

provider "awscc" {
  region  = "ap-northeast-1"              # Choose your region
  profile = "default"
}

provider "google" {
  credentials = "taaops-e9943412868a.json"    # Your JSON Key Here
  project     = var.project_id
  region      = var.region
  zone        = var.zone
}

provider "google-beta" {
  credentials = "taaops-e9943412868a.json"
  project     = var.project_id
  region      = var.region
  zone        = var.zone
}
