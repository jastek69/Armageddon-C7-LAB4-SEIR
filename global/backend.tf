# S3 native locking (Terraform >=1.10) via conditional writes — no DynamoDB table required.

# TODO: After destroying all infrastructure, standardize state key to "global/terraform.tfstate"
#       This removes the custom global022126 identifier and makes the architecture cleaner.
#       Steps: 1) terraform destroy (all stacks), 2) change key below

terraform {
  backend "s3" {
    bucket       = "taaops-terraform-state-tokyo"
    key          = "global/global022126terraform.tfstate"
    region       = "ap-northeast-1"
    encrypt      = true
    use_lockfile = true
  }
}
