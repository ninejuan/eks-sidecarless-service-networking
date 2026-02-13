variable "association_name" {
  description = "Logical name for this association (used in resource names/tags)"
  type        = string
}

variable "service_network_identifier" {
  description = "ID or ARN of the VPC Lattice service network"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC to associate"
  type        = string
}

variable "vpc_cidr_block" {
  description = "CIDR block of the VPC (used for security group ingress rules)"
  type        = string
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
