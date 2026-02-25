# VPC Endpoints for Sao Paulo (private subnets)

resource "aws_security_group" "sao_endpoints_sg" {
  name        = "sao-endpoints-sg"
  description = "Security group for Sao Paulo VPC endpoints"
  vpc_id      = aws_vpc.liberdade_vpc01.id

  ingress {
    description = "HTTPS from Sao Paulo VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.saopaulo_vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "sao-endpoints-sg"
    Region  = "SaoPaulo"
    Service = "VPCEndpoints"
  }
}

resource "aws_vpc_endpoint" "sao_ssm" {
  vpc_id              = aws_vpc.liberdade_vpc01.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssm"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [
    aws_subnet.sao_subnet_private_a.id,
    aws_subnet.sao_subnet_private_b.id,
    aws_subnet.sao_subnet_private_c.id
  ]

  security_group_ids = [aws_security_group.sao_endpoints_sg.id]

  tags = {
    Name = "sao-ssm-endpoint"
  }
}

resource "aws_vpc_endpoint" "sao_ec2messages" {
  vpc_id              = aws_vpc.liberdade_vpc01.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ec2messages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [
    aws_subnet.sao_subnet_private_a.id,
    aws_subnet.sao_subnet_private_b.id,
    aws_subnet.sao_subnet_private_c.id
  ]

  security_group_ids = [aws_security_group.sao_endpoints_sg.id]

  tags = {
    Name = "sao-ec2messages-endpoint"
  }
}

resource "aws_vpc_endpoint" "sao_ssmmessages" {
  vpc_id              = aws_vpc.liberdade_vpc01.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [
    aws_subnet.sao_subnet_private_a.id,
    aws_subnet.sao_subnet_private_b.id,
    aws_subnet.sao_subnet_private_c.id
  ]

  security_group_ids = [aws_security_group.sao_endpoints_sg.id]

  tags = {
    Name = "sao-ssmmessages-endpoint"
  }
}

resource "aws_vpc_endpoint" "sao_logs" {
  vpc_id              = aws_vpc.liberdade_vpc01.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.logs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [
    aws_subnet.sao_subnet_private_a.id,
    aws_subnet.sao_subnet_private_b.id,
    aws_subnet.sao_subnet_private_c.id
  ]

  security_group_ids = [aws_security_group.sao_endpoints_sg.id]

  tags = {
    Name = "sao-logs-endpoint"
  }
}

# S3 Gateway endpoint (private route table)
resource "aws_vpc_endpoint" "sao_s3_gateway" {
  vpc_id            = aws_vpc.liberdade_vpc01.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.sao_private_rt.id
  ]

  tags = {
    Name = "sao-s3-gateway-endpoint"
  }
}
