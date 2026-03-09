# DEPRECATED: DynamoDB state locking removed.
# Backends now use `use_lockfile = true` (S3 native conditional-write locking, Terraform >= 1.10).
# The aws_dynamodb_table.terraform_lock resource has been decommissioned.
