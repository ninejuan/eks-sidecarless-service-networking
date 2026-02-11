output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = values(aws_subnet.public)[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = values(aws_subnet.private)[*].id
}

output "public_subnet_azs" {
  description = "Public subnet AZ names"
  value       = values(aws_subnet.public)[*].availability_zone
}

output "private_subnet_azs" {
  description = "Private subnet AZ names"
  value       = values(aws_subnet.private)[*].availability_zone
}

output "private_route_table_ids" {
  description = "Private route table IDs"
  value       = values(aws_route_table.private)[*].id
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs"
  value       = values(aws_nat_gateway.this)[*].id
}
