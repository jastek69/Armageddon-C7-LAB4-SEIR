# São Paulo Backend Configuration
# S3 native locking (Terraform >=1.10) via conditional writes — no DynamoDB table required.

# TODO: After destroying all infrastructure, standardize state key to "saopaulo/terraform.tfstate"
#       This removes the custom sp022126 identifier and makes the architecture cleaner.
#       Steps: 1) terraform destroy (all stacks), 2) change key below

terraform {
  backend "s3" {
    bucket       = "taaops-terraform-state-saopaulo"
    key          = "saopaulo/sp022126terraform.tfstate"
    region       = "sa-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

# Note: Backend configurations cannot use data sources or interpolations  
# The S3 bucket for state storage should be created separately using:
# 
# resource "aws_s3_bucket" "taaops_terraform_state" {
#   bucket = "taaops-terraform-state-saopaulo-${data.aws_caller_identity.current.account_id}"
#   # Add versioning, encryption, etc.
# }
#
# Note: DynamoDB table must be created in the same region as the S3 bucket
# Use setup-dynamodb-locking.tf to create the required tables
# São Paulo reads Tokyo remote state for TGW peering and database access

