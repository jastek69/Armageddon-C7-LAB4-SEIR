terraform {
  # S3 native locking (Terraform >=1.10) via conditional writes — no DynamoDB table required.
  backend "s3" {
    bucket       = "taaops-terraform-state-tokyo"
    key          = "newyork_gcp/ny022126terraform.tfstate"
    region       = "ap-northeast-1"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.36.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.36.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.19.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
