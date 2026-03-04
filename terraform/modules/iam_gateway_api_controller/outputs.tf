output "role_arn" {
  description = "IAM role ARN for AWS Gateway API Controller (Pod Identity)"
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "IAM role name for AWS Gateway API Controller"
  value       = aws_iam_role.this.name
}

output "policy_arn" {
  description = "IAM policy ARN for AWS Gateway API Controller"
  value       = aws_iam_policy.this.arn
}