data "aws_region" "current" {}

locals {
  az_names = [for suffix in var.az_suffixes : format("%s%s", data.aws_region.current.region, suffix)]

  vpc_cidr_prefix = tonumber(split("/", var.cidr_block)[1])
  subnet_newbits  = 24 - local.vpc_cidr_prefix

  public_subnet_cidrs = [
    for idx in range(length(local.az_names)) :
    cidrsubnet(var.cidr_block, local.subnet_newbits, idx + 1)
  ]

  private_subnet_cidrs = [
    for idx in range(length(local.az_names)) :
    cidrsubnet(var.cidr_block, local.subnet_newbits, idx + 101)
  ]

  public_subnets = {
    for idx, cidr in local.public_subnet_cidrs : tostring(idx) => {
      ordinal   = idx + 1
      cidr      = cidr
      az        = local.az_names[idx]
      az_suffix = var.az_suffixes[idx]
    }
  }

  private_subnets = {
    for idx, cidr in local.private_subnet_cidrs : tostring(idx) => {
      ordinal   = idx + 1
      cidr      = cidr
      az        = local.az_names[idx]
      az_suffix = var.az_suffixes[idx]
    }
  }

  common_tags = merge(var.tags, {
    Name = var.vpc_name
  })
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = local.common_tags
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-igw"
  })
}

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name                     = format("%s-public-%s", var.vpc_name, each.value.az_suffix)
    "kubernetes.io/role/elb" = "1"
  })
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(var.tags, {
    Name                              = format("%s-private-%s", var.vpc_name, each.value.az_suffix)
    "kubernetes.io/role/internal-elb" = "1"
  })
}

resource "aws_eip" "nat" {
  for_each = local.public_subnets

  domain = "vpc"

  tags = merge(var.tags, {
    Name = format("%s-nat-eip-%d", var.vpc_name, tonumber(each.key) + 1)
  })
}

resource "aws_nat_gateway" "this" {
  for_each = aws_eip.nat

  allocation_id = each.value.id
  subnet_id     = aws_subnet.public[each.key].id

  tags = merge(var.tags, {
    Name = format("%s-nat-%d", var.vpc_name, tonumber(each.key) + 1)
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  for_each = aws_subnet.private

  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[each.key].id
  }

  tags = merge(var.tags, {
    Name = format("%s-private-rt-%d", var.vpc_name, tonumber(each.key) + 1)
  })
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}
