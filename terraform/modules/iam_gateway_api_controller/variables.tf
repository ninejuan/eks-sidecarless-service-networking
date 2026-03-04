variable "cluster_name" {
  description = "EKS cluster name (used for IAM resource naming)"
  type        = string

  validation {
    condition     = length(trimspace(var.cluster_name)) > 0
    error_message = "cluster_name must not be empty."
  }
}

variable "tags" {
  description = "Additional tags to apply to created resources"
  type        = map(string)
  default     = {}
}