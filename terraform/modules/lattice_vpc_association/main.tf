resource "aws_security_group" "lattice" {
  name        = "${var.association_name}-lattice-sg"
  description = "Security group for VPC Lattice traffic in ${var.association_name}"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.association_name}-lattice-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "lattice_http" {
  security_group_id = aws_security_group.lattice.id
  description       = "Allow HTTP from VPC"
  cidr_ipv4         = var.vpc_cidr_block
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"

  tags = merge(var.tags, {
    Name = "${var.association_name}-lattice-http"
  })
}

resource "aws_vpc_security_group_ingress_rule" "lattice_https" {
  security_group_id = aws_security_group.lattice.id
  description       = "Allow HTTPS from VPC"
  cidr_ipv4         = var.vpc_cidr_block
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"

  tags = merge(var.tags, {
    Name = "${var.association_name}-lattice-https"
  })
}

resource "aws_vpc_security_group_egress_rule" "lattice_all" {
  security_group_id = aws_security_group.lattice.id
  description       = "Allow all outbound"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"

  tags = merge(var.tags, {
    Name = "${var.association_name}-lattice-egress"
  })
}

resource "aws_vpclattice_service_network_vpc_association" "this" {
  service_network_identifier = var.service_network_identifier
  vpc_identifier             = var.vpc_id
  security_group_ids         = [aws_security_group.lattice.id]

  tags = merge(var.tags, {
    Name = "${var.association_name}-vpc-association"
  })
}
