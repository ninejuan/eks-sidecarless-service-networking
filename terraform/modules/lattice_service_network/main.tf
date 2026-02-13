resource "aws_vpclattice_service_network" "this" {
  name      = var.service_network_name
  auth_type = var.auth_type

  tags = merge(var.tags, {
    Name = var.service_network_name
  })
}

resource "aws_vpclattice_auth_policy" "this" {
  count = var.auth_type == "AWS_IAM" ? 1 : 0

  resource_identifier = aws_vpclattice_service_network.this.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "vpc-lattice-svcs:Invoke"
        Resource  = "*"
        Condition = {
          StringNotEqualsIgnoreCase = {
            "aws:PrincipalType" = "anonymous"
          }
        }
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "lattice_access_log" {
  count = var.enable_access_log ? 1 : 0

  name              = "/aws/lattice/${var.service_network_name}"
  retention_in_days = var.access_log_retention_days

  tags = merge(var.tags, {
    Name = "${var.service_network_name}_access_log"
  })
}

resource "aws_vpclattice_access_log_subscription" "this" {
  count = var.enable_access_log ? 1 : 0

  resource_identifier = aws_vpclattice_service_network.this.id
  destination_arn     = aws_cloudwatch_log_group.lattice_access_log[0].arn
}
