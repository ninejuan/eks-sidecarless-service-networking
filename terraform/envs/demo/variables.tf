variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment" {
  description = "Deployment environment name"
  type        = string
  default     = "demo"
}

variable "project_name" {
  description = "Project identifier"
  type        = string
  default     = "eks_sidecarless_service_networking"
}

variable "vpc_foo_cidr" {
  description = "CIDR block for vpc_foo"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_bar_cidr" {
  description = "CIDR block for vpc_bar"
  type        = string
  default     = "192.168.0.0/16"
}

variable "vpc_foo_az_suffixes" {
  description = "AZ suffixes for vpc_foo"
  type        = list(string)
  default     = ["a", "c"]
}

variable "vpc_bar_az_suffixes" {
  description = "AZ suffixes for vpc_bar"
  type        = list(string)
  default     = ["b", "d"]
}

variable "ecr_repository_namespace" {
  description = "Namespace for ECR repositories"
  type        = string
  default     = "demo"
}

variable "ecr_service_repositories" {
  description = "Service repositories to create in ECR"
  type        = list(string)
  default     = ["checkout", "inventory", "payment", "delivery"]
}

variable "ecr_default_image_tag_mutability" {
  description = "Default tag mutability for ECR repositories"
  type        = string
  default     = "MUTABLE"
}

variable "ecr_image_tag_mutability_overrides" {
  description = "Per-repository ECR mutability overrides"
  type        = map(string)
  default     = {}
}

variable "ecr_untagged_image_expiration_days" {
  description = "Days to expire untagged ECR images"
  type        = number
  default     = 7
}

variable "ecr_max_image_count" {
  description = "Maximum number of images to keep in ECR"
  type        = number
  default     = 30
}

variable "inventory_dynamodb_table_name" {
  description = "DynamoDB table name for inventory service"
  type        = string
  default     = "inventory_items"
}

variable "eks_kubernetes_version" {
  description = "Kubernetes version for EKS clusters"
  type        = string
  default     = "1.31"
}

variable "eks_node_instance_types" {
  description = "EC2 instance types for EKS managed node groups"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_node_scaling_config" {
  description = "Scaling configuration for EKS managed node groups"
  type = object({
    min_size     = number
    max_size     = number
    desired_size = number
  })
  default = {
    min_size     = 2
    max_size     = 5
    desired_size = 2
  }
}

variable "eks_admin_principal_arn" {
  description = "IAM principal ARN for EKS cluster admin access"
  type        = string
}

variable "eks_endpoint_public_access" {
  description = "Whether to enable public access to EKS API endpoints"
  type        = bool
  default     = true
}

variable "lattice_service_network_name" {
  description = "Name of the VPC Lattice service network (must match K8s Gateway name)"
  type        = string
  default     = "demo_service_network"
}

variable "lattice_auth_type" {
  description = "Authentication type for VPC Lattice service network"
  type        = string
  default     = "AWS_IAM"
}

variable "lattice_enable_access_log" {
  description = "Whether to enable access logging for VPC Lattice"
  type        = bool
  default     = true
}

variable "lattice_access_log_retention_days" {
  description = "Retention in days for VPC Lattice access logs"
  type        = number
  default     = 14
}

variable "common_tags" {
  description = "Additional common tags"
  type        = map(string)
  default     = {}
}
