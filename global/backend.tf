terraform {
  backend "s3" {
    bucket         = "taaops-terraform-state-tokyo"
    key            = "global/global022126terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    dynamodb_table = "taaops-terraform-state-lock"
    # use_lockfile = true # Use either this or dynamodb_table, not both.
  }
}
