# Import existing AWS resources into the Tokyo Terraform state.
# Run from PowerShell with AWS credentials configured.
# Usage: .\import_existing_resources.ps1

$ErrorActionPreference = "Stop"

function Import-Resource {
  param (
    [string]$Address,
    [string]$Id
  )

  Write-Host "Importing $Address -> $Id"
  terraform import $Address $Id
}

function Get-PolicyArn {
  param (
    [string]$PolicyName
  )

  $arn = aws iam list-policies --scope Local --query "Policies[?PolicyName=='$PolicyName'].Arn" --output text
  if (-not $arn) {
    throw "Policy ARN not found for $PolicyName"
  }
  return $arn
}

function Get-TargetGroupArn {
  param (
    [string]$Name
  )

  $arn = aws elbv2 describe-target-groups --names $Name --query "TargetGroups[0].TargetGroupArn" --output text
  if (-not $arn) {
    Write-Warning "Target group ARN not found for $Name"
    return $null
  }
  return $arn
}

function Get-LoadBalancerArn {
  param (
    [string]$Name
  )

  $arn = aws elbv2 describe-load-balancers --names $Name --query "LoadBalancers[0].LoadBalancerArn" --output text
  if (-not $arn) {
    Write-Warning "Load balancer ARN not found for $Name"
    return $null
  }
  return $arn
}

function Get-WebAclId {
  param (
    [string]$Name,
    [string]$Region
  )

  $id = aws wafv2 list-web-acls --scope REGIONAL --region $Region --query "WebACLs[?Name=='$Name'].Id" --output text
  if (-not $id) {
    Write-Warning "WAF Web ACL ID not found for $Name"
    return $null
  }
  return $id
}

function Get-WafIpSetId {
  param (
    [string]$Name,
    [string]$Region
  )

  $id = aws wafv2 list-ip-sets --scope REGIONAL --region $Region --query "IPSets[?Name=='$Name'].Id" --output text
  if (-not $id) {
    throw "WAF IP set ID not found for $Name"
  }
  return $id
}

function Test-LogGroupExists {
  param (
    [string]$Name
  )

  $found = aws logs describe-log-groups --log-group-name-prefix $Name --query "logGroups[?logGroupName=='$Name'].logGroupName" --output text
  return [bool]$found
}

function Test-SsmDocumentExists {
  param (
    [string]$Name
  )

  try {
    $null = aws ssm get-document --name $Name --query "Name" --output text
    return $true
  } catch {
    return $false
  }
}

function Test-SsmParameterExists {
  param (
    [string]$Name
  )

  try {
    $null = aws ssm get-parameter --name $Name --query "Parameter.Name" --output text
    return $true
  } catch {
    return $false
  }
}

Push-Location $PSScriptRoot

# S3 buckets
Import-Resource aws_s3_bucket.tokyo_ir_reports_bucket taaops-tokyo-incident-reports-015195098145
Import-Resource aws_s3_bucket.tokyo_backend_logs tokyo-backend-logs-015195098145
Import-Resource module.tokyo_s3_logging.aws_s3_bucket.alb_logs[0] taaops-tokyo-alb-logs
Import-Resource module.tokyo_s3_logging.aws_s3_bucket.application_logs taaops-tokyo-app-logs
Import-Resource module.tokyo_translation.aws_s3_bucket.input_bucket taaops-translate-input
Import-Resource module.tokyo_translation.aws_s3_bucket.output_bucket taaops-translate-output

# IAM roles
Import-Resource aws_iam_role.tokyo_ir_lambda_role taaops-tokyo-ir-lambda-role
Import-Resource aws_iam_role.rds_enhanced_monitoring rds-enhanced-monitoring
Import-Resource aws_iam_role.vpc_flowlogs_role tokyo-vpc-flowlogs-role
Import-Resource aws_iam_role.cloudfront_service_role cloudfront-service-role
Import-Resource aws_iam_role.lambda_edge_role lambda-edge-execution-role
Import-Resource aws_iam_role.cross_region_automation cross-region-automation-role
Import-Resource aws_iam_role.bedrock_service_role bedrock-service-role
Import-Resource aws_iam_role.route53_health_check_role route53-health-check-role
Import-Resource aws_iam_role.saopaulo_assumable_role saopaulo-assumable-role
Import-Resource module.tokyo_regional_iam.aws_iam_role.regional_ec2_role taaops-tokyo-ec2-role
Import-Resource module.tokyo_translation.aws_iam_role.translation_lambda_role taaops-translate-ap-northeast-1-lambda-role
Import-Resource aws_iam_role.tokyo_ssm_automation_role taaops-tokyo-ssm-automation-role

# IAM policies
Import-Resource aws_iam_policy.cross_region_automation (Get-PolicyArn "cross-region-automation-policy")
Import-Resource aws_iam_policy.bedrock_application_access (Get-PolicyArn "bedrock-application-access")
Import-Resource aws_iam_policy.route53_cloudwatch (Get-PolicyArn "route53-cloudwatch-policy")
Import-Resource module.tokyo_regional_iam.aws_iam_policy.regional_monitoring (Get-PolicyArn "taaops-tokyo-monitoring")
Import-Resource module.tokyo_regional_iam.aws_iam_policy.regional_application (Get-PolicyArn "taaops-tokyo-application")
Import-Resource aws_iam_policy.tokyo_ir_lambda_policy (Get-PolicyArn "taaops-tokyo-ir-lambda-policy")
Import-Resource aws_iam_policy.global_database_access (Get-PolicyArn "global-database-access")
Import-Resource aws_iam_policy.tokyo_ssm_automation_policy (Get-PolicyArn "taaops-tokyo-ssm-automation-policy")
Import-Resource module.tokyo_regional_iam.aws_iam_policy.database_access[0] (Get-PolicyArn "taaops-tokyo-database-access")
Import-Resource module.tokyo_translation.aws_iam_policy.translation_lambda_policy (Get-PolicyArn "taaops-translate-ap-northeast-1-lambda-policy")
Import-Resource module.tokyo_translation.aws_iam_policy.translation_lambda_s3_logs_policy (Get-PolicyArn "taaops-translate-ap-northeast-1-lambda-s3-logs-policy")

# RDS subnet group
Import-Resource aws_db_subnet_group.tokyo_db_subnet_group tokyo-db-private-subnet-group

# Lambda functions
Import-Resource aws_lambda_function.tokyo_ir_lambda taaops-tokyo-ir-reporter
Import-Resource module.tokyo_translation.aws_lambda_function.translation_lambda taaops-translate-ap-northeast-1-processor

# Secrets Manager
Import-Resource aws_secretsmanager_secret.db_secret taaops/rds/mysql

# DynamoDB lock table
Import-Resource aws_dynamodb_table.terraform_lock taaops-terraform-state-lock

# CloudWatch log groups (optional; only import if they exist)
if (Test-LogGroupExists "/vpc/flowlogs/tokyo-rds") {
  Import-Resource aws_cloudwatch_log_group.tokyo_rds_flowlogs /vpc/flowlogs/tokyo-rds
}
if (Test-LogGroupExists "/taaops/application") {
  Import-Resource aws_cloudwatch_log_group.taaops_cw_log_group01 /taaops/application
}
if (Test-LogGroupExists "/aws/taaops-tokyo/application") {
  Import-Resource module.tokyo_monitoring.aws_cloudwatch_log_group.application /aws/taaops-tokyo/application
}
if (Test-LogGroupExists "/aws/taaops-tokyo/system") {
  Import-Resource module.tokyo_monitoring.aws_cloudwatch_log_group.system /aws/taaops-tokyo/system
}
if (Test-LogGroupExists "/aws/taaops-tokyo/alb") {
  Import-Resource module.tokyo_monitoring.aws_cloudwatch_log_group.alb /aws/taaops-tokyo/alb
}
if (Test-LogGroupExists "aws-waf-logs-taaops-tokyo-regional-waf") {
  Import-Resource aws_cloudwatch_log_group.taaops_regional_waf_log_group[0] aws-waf-logs-taaops-tokyo-regional-waf
}

# SSM (optional; only import if they exist)
if (Test-SsmDocumentExists "taaops-tokyo-incident-report") {
  Import-Resource aws_ssm_document.tokyo_alarm_report_runbook taaops-tokyo-incident-report
}
if (Test-SsmParameterExists "/cw/agent/config") {
  Import-Resource module.tokyo_monitoring.aws_ssm_parameter.cw_agent_config /cw/agent/config
}

# ALB target group (optional; only import if it exists)
$tgArn = Get-TargetGroupArn "taaops-tokyo-tg80"
if ($tgArn) {
  Import-Resource aws_lb_target_group.tokyo_tg80 $tgArn
}

# ALB (optional; only import if it exists)
$albArn = Get-LoadBalancerArn "taaops-tokyo-alb"
if ($albArn) {
  Import-Resource aws_lb.tokyo_alb $albArn
}

# KMS alias
Import-Resource aws_kms_alias.taaops_kms_alias01 alias/taaops-key01

# IAM instance profile
Import-Resource module.tokyo_regional_iam.aws_iam_instance_profile.regional_ec2_instance_profile taaops-tokyo-ec2-instance-profile

# WAFv2 IP set (optional; only import if it exists)
try {
  $wafIpSetId = Get-WafIpSetId -Name "taaops-tokyo-ip-block-list" -Region "ap-northeast-1"
  if ($wafIpSetId) {
    Import-Resource aws_wafv2_ip_set.taaops_regional_ip_block_list "$wafIpSetId/taaops-tokyo-ip-block-list/REGIONAL"
  }
} catch {
  Write-Warning "WAF IP set not found: taaops-tokyo-ip-block-list"
}

# WAFv2 Web ACL (optional; only import if it exists)
$webAclId = Get-WebAclId -Name "taaops-tokyo-regional-waf" -Region "ap-northeast-1"
if ($webAclId) {
  Import-Resource aws_wafv2_web_acl.taaops_regional_waf_acl "$webAclId/taaops-tokyo-regional-waf/REGIONAL"
}

Pop-Location

Write-Host "Import complete. Next: terraform plan in Tokyo, then re-run root apply."