output "association_id" {
  description = "ID of the VPC Lattice service network VPC association"
  value       = aws_vpclattice_service_network_vpc_association.this.id
}

output "association_arn" {
  description = "ARN of the VPC Lattice service network VPC association"
  value       = aws_vpclattice_service_network_vpc_association.this.arn
}

output "security_group_id" {
  description = "ID of the security group created for Lattice traffic"
  value       = aws_security_group.lattice.id
}
