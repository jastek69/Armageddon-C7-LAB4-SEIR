############################################
# Secrets Manager Rotation (Tokyo)
############################################

# Security group for the rotation Lambda (no ingress; egress to DB).
resource "aws_security_group" "tokyo_secrets_rotation_lambda_sg" {
  name        = "tokyo-secrets-rotation-lambda-sg"
  description = "Security group for Secrets Manager rotation Lambda"
  vpc_id      = aws_vpc.shinjuku_vpc01.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name    = "tokyo-secrets-rotation-lambda-sg"
    Purpose = "SecretsRotation"
    Region  = "Tokyo"
  })
}

# Allow rotation Lambda to reach the database SG (even if the DB SG is external).
resource "aws_security_group_rule" "allow_secrets_rotation_to_rds" {
  type                     = "ingress"
  security_group_id        = local.rds_security_group_id
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.tokyo_secrets_rotation_lambda_sg.id
  description              = "MySQL from Secrets Manager rotation Lambda"
}

# IAM role for the rotation Lambda.
resource "aws_iam_role" "tokyo_secrets_rotation_lambda_role" {
  name = "${var.project_name}-secrets-rotation-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-secrets-rotation-lambda-role"
    Purpose = "SecretsRotation"
    Region  = "Tokyo"
  })
}

resource "aws_iam_role_policy_attachment" "tokyo_secrets_rotation_lambda_basic" {
  role       = aws_iam_role.tokyo_secrets_rotation_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "tokyo_secrets_rotation_lambda_vpc" {
  role       = aws_iam_role.tokyo_secrets_rotation_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Permissions for rotating the RDS secret.
data "aws_iam_policy_document" "tokyo_secrets_rotation" {
  statement {
    sid    = "SecretsManagerRotation"
    effect = "Allow"
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
      "secretsmanager:PutSecretValue",
      "secretsmanager:UpdateSecretVersionStage",
      "secretsmanager:ListSecretVersionIds",
      "secretsmanager:GetRandomPassword"
    ]
    resources = [aws_secretsmanager_secret.db_secret.arn]
  }

  statement {
    sid    = "KmsDecryptForSecrets"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]
    resources = [local.rds_kms_key_arn]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["secretsmanager.${data.aws_region.current.name}.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "tokyo_secrets_rotation" {
  name   = "${var.project_name}-secrets-rotation-policy"
  policy = data.aws_iam_policy_document.tokyo_secrets_rotation.json
}

resource "aws_iam_role_policy_attachment" "tokyo_secrets_rotation_attach" {
  role       = aws_iam_role.tokyo_secrets_rotation_lambda_role.name
  policy_arn = aws_iam_policy.tokyo_secrets_rotation.arn
}

# Rotation Lambda function.
resource "aws_lambda_function" "tokyo_secrets_rotation" {
  filename         = "${path.module}/../lambda/SecretsManagertaaops-lab1-asm-rotation.zip"
  function_name    = "SecretsManagertaaops-lab1-asm-rotation"
  role             = aws_iam_role.tokyo_secrets_rotation_lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.10"
  source_code_hash = filebase64sha256("${path.module}/../lambda/SecretsManagertaaops-lab1-asm-rotation.zip")
  timeout          = 30
  memory_size      = 256

  vpc_config {
    subnet_ids = [
      aws_subnet.tokyo_subnet_private_a.id,
      aws_subnet.tokyo_subnet_private_b.id,
      aws_subnet.tokyo_subnet_private_c.id
    ]
    security_group_ids = [aws_security_group.tokyo_secrets_rotation_lambda_sg.id]
  }

  tags = merge(var.common_tags, {
    Name    = "SecretsManagertaaops-lab1-asm-rotation"
    Purpose = "SecretsRotation"
    Region  = "Tokyo"
  })
}

# Allow Secrets Manager to invoke the rotation Lambda.
resource "aws_lambda_permission" "tokyo_allow_secretsmanager_invoke" {
  statement_id  = "AllowSecretsManagerInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.tokyo_secrets_rotation.function_name
  principal     = "secretsmanager.amazonaws.com"
  source_arn    = aws_secretsmanager_secret.db_secret.arn
}

# Rotate the RDS secret on a schedule.
resource "aws_secretsmanager_secret_rotation" "tokyo_db_secret_rotation" {
  secret_id           = aws_secretsmanager_secret.db_secret.id
  rotation_lambda_arn = aws_lambda_function.tokyo_secrets_rotation.arn
  depends_on          = [aws_secretsmanager_secret_version.tokyo_db_secret_initial]

  rotation_rules {
    automatically_after_days = var.secrets_rotation_days
  }
}
