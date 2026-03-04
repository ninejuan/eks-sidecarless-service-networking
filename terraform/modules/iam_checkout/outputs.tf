output "role_arn" {
  description = "IAM role ARN for checkout service (IRSA)"
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "IAM role name for checkout service"
  value       = aws_iam_role.this.name
}

output "policy_arn" {
  description = "IAM policy ARN for checkout service"
  value       = aws_iam_policy.this.arn
}
