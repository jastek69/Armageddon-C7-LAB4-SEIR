terraform {
  backend "s3" {
    bucket         = "taaops-terraform-state-tokyo"
    key            = "newyork_gcp/ny02152026terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    use_lockfile   = true
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
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
