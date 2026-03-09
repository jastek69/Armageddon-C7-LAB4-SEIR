# S3 native locking (Terraform >=1.10) via conditional writes — no DynamoDB table required.
terraform {
  backend "s3" {
    bucket       = "taaops-terraform-state-tokyo"
    key          = "global/global022126terraform.tfstate"
    region       = "ap-northeast-1"
    encrypt      = true
    use_lockfile = true
  }
}
