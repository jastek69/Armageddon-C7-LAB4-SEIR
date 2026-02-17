resource "aws_cloudwatch_log_group" "tokyo_rds_flowlogs" {
  name              = "/vpc/flowlogs/tokyo-rds"
  retention_in_days = 7

  tags = {
    Name = "tokyo-rds-flowlogs"
  }
}

resource "aws_iam_role" "vpc_flowlogs_role" {
  name = "tokyo-vpc-flowlogs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "vpc_flowlogs_policy" {
  name = "tokyo-vpc-flowlogs-policy"
  role = aws_iam_role.vpc_flowlogs_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

locals {
  tokyo_rds_flowlog_subnets = [
    aws_subnet.tokyo_subnet_private_a.id,
    aws_subnet.tokyo_subnet_private_b.id,
    aws_subnet.tokyo_subnet_private_c.id
  ]
}

resource "aws_flow_log" "tokyo_rds_subnet_flowlogs" {
  for_each = toset(local.tokyo_rds_flowlog_subnets)

  log_destination      = aws_cloudwatch_log_group.tokyo_rds_flowlogs.arn
  log_destination_type = "cloud-watch-logs"
  traffic_type         = "REJECT" # Only log rejected traffic to reduce noise and focus on potential issues. - set ALL for troubleshooting or if you want to analyze accepted traffic patterns.
  iam_role_arn         = aws_iam_role.vpc_flowlogs_role.arn
  subnet_id            = each.value

  tags = {
    Name = "tokyo-rds-subnet-flowlogs"
  }
}

resource "aws_cloudwatch_log_metric_filter" "tokyo_rds_flowlog_rejects" {
  count = var.enable_rds_flowlog_alarm ? 1 : 0

  name           = "tokyo-rds-flowlog-rejects"
  log_group_name = aws_cloudwatch_log_group.tokyo_rds_flowlogs.name
  pattern        = "REJECT"

  metric_transformation {
    name      = "RdsFlowlogRejects"
    namespace = "Taaops/Network"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "tokyo_rds_flowlog_rejects" {
  count = var.enable_rds_flowlog_alarm ? 1 : 0

  alarm_name          = "tokyo-rds-flowlog-rejects"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.tokyo_rds_flowlog_rejects[0].metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.tokyo_rds_flowlog_rejects[0].metric_transformation[0].namespace
  period              = 60
  statistic           = "Sum"
  threshold           = 1

  alarm_description = "Detects REJECT entries in Tokyo RDS subnet flow logs."
  alarm_actions     = [aws_sns_topic.tokyo_ir_reports_topic.arn]

  tags = {
    Name = "tokyo-rds-flowlog-rejects"
  }
}
