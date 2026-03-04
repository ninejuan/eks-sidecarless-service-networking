# -----------------------------------------------------------------------------
# Inventory Service IAM — IRSA based
# Grants the inventory Kubernetes ServiceAccount permission to access DynamoDB.
# Trust policy uses OIDC federation so only the inventory SA can assume this role.
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
  name               = "${var.cluster_name}-inventory"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = merge(var.tags, { Name = "${var.cluster_name}-inventory" })
}

resource "aws_iam_policy" "this" {
  name        = "${var.cluster_name}-inventory"
  description = "IAM policy for inventory service DynamoDB access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:Scan",
        ]
        Resource = [
          var.dynamodb_table_arn,
          "${var.dynamodb_table_arn}/index/*",
        ]
      },
    ]
  })

  tags = merge(var.tags, { Name = "${var.cluster_name}-inventory-policy" })
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}
