output "repository_names" {
  description = "ECR repository names keyed by service"
  value       = { for name, repo in aws_ecr_repository.this : name => repo.name }
}

output "repository_urls" {
  description = "ECR repository URLs keyed by service"
  value       = { for name, repo in aws_ecr_repository.this : name => repo.repository_url }
}

output "repository_arns" {
  description = "ECR repository ARNs keyed by service"
  value       = { for name, repo in aws_ecr_repository.this : name => repo.arn }
}
