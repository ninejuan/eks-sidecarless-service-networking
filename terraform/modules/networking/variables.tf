variable "vpc_name" {
  description = "Logical name of the VPC"
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "az_suffixes" {
  description = "AZ suffixes to use in the selected region (example: [\"a\", \"c\"])"
  type        = list(string)

  validation {
    condition     = length(var.az_suffixes) == 2
    error_message = "az_suffixes must include exactly 2 AZ suffixes for this demo."
  }
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs (must match az_suffixes length)"
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "public_subnet_cidrs must include exactly 2 CIDRs."
  }
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs (must match az_suffixes length)"
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_cidrs) == 2
    error_message = "private_subnet_cidrs must include exactly 2 CIDRs."
  }
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway for all private subnets"
  type        = bool
  default     = true
}

variable "create_nat_gateway" {
  description = "Create NAT Gateway resources"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support on VPC"
  type        = bool
  default     = true
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames on VPC"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
