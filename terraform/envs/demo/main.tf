locals {
  name_prefix = format("summit-%s", var.environment)

  vpc_foo_name = format("%s-foo-vpc", local.name_prefix)
  vpc_bar_name = format("%s-bar-vpc", local.name_prefix)

  eks_foo_name = format("summit-%s-foo-cluster", var.environment)
  eks_bar_name = format("summit-%s-bar-cluster", var.environment)

  lattice_service_network_name = format("%s-service-network", local.name_prefix)
  lattice_vpc_association_foo  = format("%s-foo-vpc-association", local.name_prefix)
  lattice_vpc_association_bar  = format("%s-bar-vpc-association", local.name_prefix)

  ecr_repository_namespace      = local.name_prefix
  inventory_dynamodb_table_name = format("%s-inventory-items", local.name_prefix)

  tags = merge(var.common_tags, {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  })
}

# -----------------------------------------------------------------------------
# Networking
# -----------------------------------------------------------------------------

module "vpc_foo" {
  source = "../../modules/networking"

  vpc_name    = local.vpc_foo_name
  cidr_block  = var.vpc_foo_cidr
  az_suffixes = var.vpc_foo_az_suffixes
  tags        = merge(local.tags, { component = "networking", scope = "foo" })
}

module "vpc_bar" {
  source = "../../modules/networking"

  vpc_name    = local.vpc_bar_name
  cidr_block  = var.vpc_bar_cidr
  az_suffixes = var.vpc_bar_az_suffixes
  tags        = merge(local.tags, { component = "networking", scope = "bar" })
}

# -----------------------------------------------------------------------------
# EKS Clusters
# -----------------------------------------------------------------------------

module "eks_foo" {
  source = "../../modules/eks"

  cluster_name       = local.eks_foo_name
  kubernetes_version = var.eks_kubernetes_version

  vpc_id         = module.vpc_foo.vpc_id
  vpc_cidr_block = module.vpc_foo.vpc_cidr_block
  subnet_ids     = module.vpc_foo.private_subnet_ids

  node_instance_types = var.eks_node_instance_types
  node_scaling_config = var.eks_node_scaling_config

  enable_access_entry = var.eks_enable_access_entry
  admin_principal_arn = var.eks_admin_principal_arn

  endpoint_public_access = var.eks_endpoint_public_access

  tags = merge(local.tags, { component = "eks", scope = "foo" })
}

module "eks_bar" {
  source = "../../modules/eks"

  cluster_name       = local.eks_bar_name
  kubernetes_version = var.eks_kubernetes_version

  vpc_id         = module.vpc_bar.vpc_id
  vpc_cidr_block = module.vpc_bar.vpc_cidr_block
  subnet_ids     = module.vpc_bar.private_subnet_ids

  node_instance_types = var.eks_node_instance_types
  node_scaling_config = var.eks_node_scaling_config

  enable_access_entry = var.eks_enable_access_entry
  admin_principal_arn = var.eks_admin_principal_arn

  endpoint_public_access = var.eks_endpoint_public_access

  tags = merge(local.tags, { component = "eks", scope = "bar" })
}

# -----------------------------------------------------------------------------
# VPC Lattice
# -----------------------------------------------------------------------------

module "lattice_service_network" {
  source = "../../modules/lattice_service_network"

  service_network_name = local.lattice_service_network_name
  auth_type            = var.lattice_auth_type

  enable_access_log         = var.lattice_enable_access_log
  access_log_retention_days = var.lattice_access_log_retention_days

  tags = merge(local.tags, { component = "lattice" })
}

module "lattice_vpc_association_foo" {
  source = "../../modules/lattice_vpc_association"

  association_name           = local.lattice_vpc_association_foo
  service_network_identifier = module.lattice_service_network.service_network_id
  vpc_id                     = module.vpc_foo.vpc_id
  vpc_cidr_block             = module.vpc_foo.vpc_cidr_block
  tags                       = merge(local.tags, { component = "lattice", scope = "foo" })
}

module "lattice_vpc_association_bar" {
  source = "../../modules/lattice_vpc_association"

  association_name           = local.lattice_vpc_association_bar
  service_network_identifier = module.lattice_service_network.service_network_id
  vpc_id                     = module.vpc_bar.vpc_id
  vpc_cidr_block             = module.vpc_bar.vpc_cidr_block
  tags                       = merge(local.tags, { component = "lattice", scope = "bar" })
}

# -----------------------------------------------------------------------------
# Shared App Resources
# -----------------------------------------------------------------------------

module "ecr" {
  source = "../../modules/ecr"

  repository_namespace = local.ecr_repository_namespace
  repositories         = var.ecr_service_repositories

  scan_on_push = true

  default_image_tag_mutability   = var.ecr_default_image_tag_mutability
  image_tag_mutability_overrides = var.ecr_image_tag_mutability_overrides
  untagged_image_expiration_days = var.ecr_untagged_image_expiration_days
  max_image_count                = var.ecr_max_image_count

  tags = merge(local.tags, { component = "ecr" })
}

module "dynamodb" {
  source = "../../modules/dynamodb"

  table_name = local.inventory_dynamodb_table_name

  billing_mode  = "PAY_PER_REQUEST"
  hash_key      = "sku"
  hash_key_type = "S"

  point_in_time_recovery_enabled = true

  tags = merge(local.tags, { component = "dynamodb", service = "inventory" })
}
