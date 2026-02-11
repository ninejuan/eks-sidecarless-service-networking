data "aws_region" "current" {}

locals {
  az_names = [for suffix in var.az_suffixes : format("%s%s", data.aws_region.current.region, suffix)]

  public_subnets = {
    for idx, cidr in var.public_subnet_cidrs : tostring(idx) => {
      ordinal = idx + 1
      cidr    = cidr
      az      = local.az_names[idx]
    }
  }

  private_subnets = {
    for idx, cidr in var.private_subnet_cidrs : tostring(idx) => {
      ordinal = idx + 1
      cidr    = cidr
      az      = local.az_names[idx]
    }
  }

  nat_gateway_keys = var.create_nat_gateway ? (
    var.single_nat_gateway ? ["0"] : keys(local.public_subnets)
  ) : []

  common_tags = merge(var.tags, {
    Name = var.vpc_name
  })
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames

  tags = local.common_tags
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.vpc_name}_igw"
  })
}

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name                     = format("%s_public_%d", var.vpc_name, each.value.ordinal)
    "kubernetes.io/role/elb" = "1"
  })
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(var.tags, {
    Name                              = format("%s_private_%d", var.vpc_name, each.value.ordinal)
    "kubernetes.io/role/internal-elb" = "1"
  })
}

resource "aws_eip" "nat" {
  for_each = toset(local.nat_gateway_keys)

  domain = "vpc"

  tags = merge(var.tags, {
    Name = format("%s_nat_eip_%d", var.vpc_name, tonumber(each.key) + 1)
  })
}

resource "aws_nat_gateway" "this" {
  for_each = aws_eip.nat

  allocation_id = each.value.id
  subnet_id     = aws_subnet.public[each.key].id

  tags = merge(var.tags, {
    Name = format("%s_nat_%d", var.vpc_name, tonumber(each.key) + 1)
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
    Name = "${var.vpc_name}_public_rt"
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

  dynamic "route" {
    for_each = var.create_nat_gateway ? [1] : []

    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.this["0"].id : aws_nat_gateway.this[each.key].id
    }
  }

  tags = merge(var.tags, {
    Name = format("%s_private_rt_%d", var.vpc_name, each.value.ordinal)
  })
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}
