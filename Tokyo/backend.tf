# Tokyo Backend Configuration
# S3 native locking (Terraform >=1.10) via conditional writes — no DynamoDB table required.

# TODO: After destroying all infrastructure, standardize state key to "tokyo/terraform.tfstate"
#       This removes the custom tk022126 identifier and makes the architecture cleaner.
#       Steps: 1) terraform destroy (all stacks), 2) change key below, 3) update global/variables.tf

terraform {
  backend "s3" {
    bucket       = "taaops-terraform-state-tokyo"
    key          = "tokyo/tk022126terraform.tfstate"
    region       = "ap-northeast-1"
    encrypt      = true
    use_lockfile = true
  }
}

# Note: Backend configurations cannot use data sources or interpolations
# The S3 bucket for state storage should be created separately using:
# 
# resource "aws_s3_bucket" "tokyo_backend_logs" {
#   bucket = "taaops-terraform-state-tokyo-${data.aws_caller_identity.taaops_self01.account_id}"
#   # Add versioning, encryption, etc.
# }
#
# Benefits of DynamoDB State Locking:
# 1. Prevents concurrent Terraform runs from corrupting state
# 2. Essential for team environments and CI/CD pipelines
# 3. Provides atomic operations and consistency
# 4. Minimal cost - only charged for actual lock operations