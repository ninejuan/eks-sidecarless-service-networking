# -----------------------------------------------------------------------------
# Checkout Service IAM — IRSA based
# Grants the checkout Kubernetes ServiceAccount permission to invoke
# VPC Lattice services via SigV4-signed requests.
# Trust policy uses OIDC federation so only the checkout SA can assume this role.
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
  name               = "${var.cluster_name}-checkout"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = merge(var.tags, { Name = "${var.cluster_name}-checkout" })
}

resource "aws_iam_policy" "this" {
  name        = "${var.cluster_name}-checkout"
  description = "IAM policy for checkout service VPC Lattice access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "vpc-lattice-svcs:Invoke"
        Resource = "*"
      },
    ]
  })

  tags = merge(var.tags, { Name = "${var.cluster_name}-checkout-policy" })
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}
