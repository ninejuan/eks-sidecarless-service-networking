output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "API server endpoint of the EKS cluster"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate authority data for the EKS cluster"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "Cluster security group ID created by EKS"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for the EKS cluster"
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider for IRSA"
  value       = aws_iam_openid_connect_provider.this.arn
}

output "node_role_arn" {
  description = "ARN of the IAM role used by managed worker nodes"
  value       = aws_iam_role.node.arn
}

output "cluster_role_arn" {
  description = "ARN of the IAM role used by the EKS control plane"
  value       = aws_iam_role.cluster.arn
}

output "node_security_group_id" {
  description = "Security group ID used by managed worker nodes"
  value       = aws_security_group.node.id
}
