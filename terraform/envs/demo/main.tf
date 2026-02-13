locals {
  eks_foo_name = "eks_foo"
  eks_bar_name = "eks_bar"

  tags = merge(var.common_tags, {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  })
}

module "vpc_foo" {
  source = "../../modules/networking"

  vpc_name    = "vpc_foo"
  cidr_block  = var.vpc_foo_cidr
  az_suffixes = var.vpc_foo_az_suffixes
  tags        = merge(local.tags, { component = "networking", scope = "foo" })
}

module "vpc_bar" {
  source = "../../modules/networking"

  vpc_name    = "vpc_bar"
  cidr_block  = var.vpc_bar_cidr
  az_suffixes = var.vpc_bar_az_suffixes
  tags        = merge(local.tags, { component = "networking", scope = "bar" })
}

module "ecr" {
  source = "../../modules/ecr"

  repository_namespace           = var.ecr_repository_namespace
  repositories                   = var.ecr_service_repositories
  scan_on_push                   = true
  default_image_tag_mutability   = var.ecr_default_image_tag_mutability
  image_tag_mutability_overrides = var.ecr_image_tag_mutability_overrides
  untagged_image_expiration_days = var.ecr_untagged_image_expiration_days
  max_image_count                = var.ecr_max_image_count
  tags                           = merge(local.tags, { component = "ecr" })
}

module "dynamodb" {
  source = "../../modules/dynamodb"

  table_name                     = var.inventory_dynamodb_table_name
  billing_mode                   = "PAY_PER_REQUEST"
  hash_key                       = "sku"
  hash_key_type                  = "S"
  point_in_time_recovery_enabled = true
  tags                           = merge(local.tags, { component = "dynamodb", service = "inventory" })
}
