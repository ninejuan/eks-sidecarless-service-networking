variable "service_network_name" {
  description = "Name of the VPC Lattice service network. IMPORTANT: This name must match the K8s Gateway resource name for the AWS Gateway API Controller to reference it."
  type        = string
}

variable "auth_type" {
  description = "Authentication type for the VPC Lattice service network"
  type        = string
  default     = "AWS_IAM"

  validation {
    condition     = contains(["NONE", "AWS_IAM"], var.auth_type)
    error_message = "auth_type must be one of: NONE, AWS_IAM."
  }
}

variable "enable_access_log" {
  description = "Whether to create CloudWatch log group and access log subscription"
  type        = bool
  default     = true
}

variable "access_log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
