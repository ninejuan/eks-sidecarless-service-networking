# -----------------------------------------------------------------------------
# Gateway API Controller IAM — IRSA based
# The controller deployment is managed in kubernetes/ layer (Kustomize).
# Terraform provisions the IAM role and policy so that the controller can
# manage VPC Lattice resources. Trust policy uses OIDC federation so only
# the gateway-api-controller SA can assume this role.
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_issuer}:sub"
      values   = ["system:serviceaccount:${var.service_account_namespace}:${var.service_account_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
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