# -----------------------------------------------------------------------------
# Gateway API Controller IAM — Pod Identity based
# The controller deployment and Pod Identity Association are managed in
# kubernetes/ layer (Kustomize). Terraform only provisions the IAM role
# and policy so that the controller can manage VPC Lattice resources.
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole", "sts:TagSession"]
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.cluster_name}-gateway-api-controller"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = merge(var.tags, { Name = "${var.cluster_name}-gateway-api-controller" })
}

resource "aws_iam_policy" "this" {
  name        = "${var.cluster_name}-gateway-api-controller"
  description = "IAM policy for AWS Gateway API Controller (VPC Lattice)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "vpc-lattice:*",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeTags",
          "ec2:DescribeSecurityGroups",
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:DescribeLogGroups",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "tag:GetResources",
          "tag:TagResources",
          "tag:UntagResources",
          "firehose:TagDeliveryStream",
          "s3:GetBucketPolicy",
          "s3:PutBucketPolicy",
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = "iam:CreateServiceLinkedRole"
        Resource = "arn:aws:iam::*:role/aws-service-role/vpc-lattice.amazonaws.com/AWSServiceRoleForVpcLattice"
        Condition = {
          StringLike = {
            "iam:AWSServiceName" = "vpc-lattice.amazonaws.com"
          }
        }
      },
      {
        Effect   = "Allow"
        Action   = "iam:CreateServiceLinkedRole"
        Resource = "arn:aws:iam::*:role/aws-service-role/delivery.logs.amazonaws.com/AWSServiceRoleForLogDelivery"
        Condition = {
          StringLike = {
            "iam:AWSServiceName" = "delivery.logs.amazonaws.com"
          }
        }
      },
    ]
  })

  tags = merge(var.tags, { Name = "${var.cluster_name}-gateway-api-controller-policy" })
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}