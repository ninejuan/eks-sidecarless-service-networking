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

variable "vpc_foo_public_subnet_cidrs" {
  description = "Public subnet CIDRs for vpc_foo"
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "vpc_foo_private_subnet_cidrs" {
  description = "Private subnet CIDRs for vpc_foo"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "vpc_bar_public_subnet_cidrs" {
  description = "Public subnet CIDRs for vpc_bar"
  type        = list(string)
  default     = ["192.168.0.0/24", "192.168.1.0/24"]
}

variable "vpc_bar_private_subnet_cidrs" {
  description = "Private subnet CIDRs for vpc_bar"
  type        = list(string)
  default     = ["192.168.10.0/24", "192.168.11.0/24"]
}

variable "single_nat_gateway" {
  description = "Use single NAT gateway per VPC"
  type        = bool
  default     = true
}

variable "create_nat_gateway" {
  description = "Create NAT gateways"
  type        = bool
  default     = true
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

variable "common_tags" {
  description = "Additional common tags"
  type        = map(string)
  default     = {}
}
