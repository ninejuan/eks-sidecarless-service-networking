variable "cluster_name" {
  description = "Logical name of the EKS cluster"
  type        = string

  validation {
    condition     = length(trimspace(var.cluster_name)) > 0
    error_message = "cluster_name must not be empty."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS control plane"
  type        = string
  default     = "1.31"

  validation {
    condition     = can(regex("^1\\.[0-9]{2}$", var.kubernetes_version))
    error_message = "kubernetes_version must match major.minor format like 1.31."
  }
}

variable "vpc_id" {
  description = "VPC ID to deploy into"
  type        = string

  validation {
    condition     = can(regex("^vpc-[a-z0-9]+$", var.vpc_id))
    error_message = "vpc_id must be a valid VPC ID (for example, vpc-abc1234567890def0)."
  }
}

variable "subnet_ids" {
  description = "Private subnet IDs for cluster and nodes"
  type        = list(string)

  validation {
    condition = length(var.subnet_ids) > 0 && alltrue([
      for subnet_id in var.subnet_ids : can(regex("^subnet-[a-z0-9]+$", subnet_id))
    ])
    error_message = "subnet_ids must contain at least one valid subnet ID."
  }
}

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group"
  type        = list(string)
  default     = ["t3.medium"]

  validation {
    condition     = length(var.node_instance_types) > 0
    error_message = "node_instance_types must contain at least one instance type."
  }
}

variable "node_scaling_config" {
  description = "Managed node group scaling configuration"
  type = object({
    min_size     = number
    max_size     = number
    desired_size = number
  })
  default = {
    min_size     = 2
    max_size     = 5
    desired_size = 2
  }

  validation {
    condition = (
      var.node_scaling_config.min_size >= 1 &&
      var.node_scaling_config.max_size >= var.node_scaling_config.min_size &&
      var.node_scaling_config.desired_size >= var.node_scaling_config.min_size &&
      var.node_scaling_config.desired_size <= var.node_scaling_config.max_size
    )
    error_message = "node_scaling_config must satisfy min_size >= 1 and min_size <= desired_size <= max_size."
  }
}

variable "admin_principal_arn" {
  description = "IAM principal ARN for cluster admin access"
  type        = string

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:.+$", var.admin_principal_arn))
    error_message = "admin_principal_arn must be a valid IAM principal ARN."
  }
}

variable "endpoint_public_access" {
  description = "Whether to enable public access to the Kubernetes API endpoint"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags to apply to created resources"
  type        = map(string)
  default     = {}
}
