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

output "vpc_foo_public_subnet_ids" {
  description = "Public subnet IDs for vpc_foo (used for ALB)"
  value       = module.vpc_foo.public_subnet_ids
}

output "vpc_bar_private_subnet_ids" {
  description = "Private subnet IDs for vpc_bar"
  value       = module.vpc_bar.private_subnet_ids
}

output "eks_foo_cluster_name" {
  description = "EKS cluster name for foo"
  value       = module.eks_foo.cluster_name
}

output "eks_foo_cluster_endpoint" {
  description = "EKS API endpoint for foo"
  value       = module.eks_foo.cluster_endpoint
}

output "eks_foo_oidc_provider_arn" {
  description = "OIDC provider ARN for eks_foo (IRSA)"
  value       = module.eks_foo.oidc_provider_arn
}

output "eks_foo_node_security_group_id" {
  description = "Node security group ID for eks_foo"
  value       = module.eks_foo.node_security_group_id
}

output "eks_foo_gateway_api_controller_role_arn" {
  description = "Gateway API Controller IAM role ARN for eks_foo"
  value       = module.iam_gateway_api_controller_foo.role_arn
}

output "eks_foo_lb_controller_role_arn" {
  description = "AWS LB Controller IAM role ARN for eks_foo"
  value       = module.iam_lb_controller_foo.role_arn
}

output "eks_bar_cluster_name" {
  description = "EKS cluster name for bar"
  value       = module.eks_bar.cluster_name
}

output "eks_bar_cluster_endpoint" {
  description = "EKS API endpoint for bar"
  value       = module.eks_bar.cluster_endpoint
}

output "eks_bar_oidc_provider_arn" {
  description = "OIDC provider ARN for eks_bar (IRSA)"
  value       = module.eks_bar.oidc_provider_arn
}

output "eks_bar_node_security_group_id" {
  description = "Node security group ID for eks_bar"
  value       = module.eks_bar.node_security_group_id
}

output "eks_bar_gateway_api_controller_role_arn" {
  description = "Gateway API Controller IAM role ARN for eks_bar"
  value       = module.iam_gateway_api_controller_bar.role_arn
}

output "lattice_service_network_id" {
  description = "VPC Lattice service network ID"
  value       = module.lattice_service_network.service_network_id
}

output "lattice_service_network_arn" {
  description = "VPC Lattice service network ARN"
  value       = module.lattice_service_network.service_network_arn
}

output "ecr_repository_urls" {
  description = "ECR repository URLs keyed by service"
  value       = module.ecr.repository_urls
}

output "inventory_dynamodb_table_name" {
  description = "Inventory DynamoDB table name"
  value       = module.dynamodb.table_name
}

output "inventory_role_arn" {
  description = "Inventory service IAM role ARN (IRSA)"
  value       = module.iam_inventory.role_arn
}

output "checkout_role_arn" {
  description = "Checkout service IAM role ARN (IRSA)"
  value       = module.iam_checkout.role_arn
}

output "region" {
  description = "AWS region"
  value       = var.region
}
