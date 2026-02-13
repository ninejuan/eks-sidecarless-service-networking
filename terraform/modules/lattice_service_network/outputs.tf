output "service_network_id" {
  description = "ID of the VPC Lattice service network"
  value       = aws_vpclattice_service_network.this.id
}

output "service_network_arn" {
  description = "ARN of the VPC Lattice service network"
  value       = aws_vpclattice_service_network.this.arn
}

output "service_network_name" {
  description = "Name of the VPC Lattice service network"
  value       = aws_vpclattice_service_network.this.name
}
