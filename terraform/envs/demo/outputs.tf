output "eks_foo_name" {
  description = "Planned EKS cluster name for foo"
  value       = local.eks_foo_name
}

output "eks_bar_name" {
  description = "Planned EKS cluster name for bar"
  value       = local.eks_bar_name
}

output "vpc_foo_id" {
  description = "ID of vpc_foo"
  value       = module.vpc_foo.vpc_id
}

output "vpc_bar_id" {
  description = "ID of vpc_bar"
  value       = module.vpc_bar.vpc_id
}

output "vpc_foo_private_subnet_ids" {
  description = "Private subnet IDs for vpc_foo"
  value       = module.vpc_foo.private_subnet_ids
}

output "vpc_bar_private_subnet_ids" {
  description = "Private subnet IDs for vpc_bar"
  value       = module.vpc_bar.private_subnet_ids
}

output "ecr_repository_urls" {
  description = "ECR repository URLs keyed by service"
  value       = module.ecr.repository_urls
}

output "inventory_dynamodb_table_name" {
  description = "Inventory DynamoDB table name"
  value       = module.dynamodb.table_name
}
