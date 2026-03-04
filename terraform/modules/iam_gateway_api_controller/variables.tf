variable "cluster_name" {
  description = "EKS cluster name (used for IAM resource naming)"
  type        = string

  validation {
    condition     = length(trimspace(var.cluster_name)) > 0
    error_message = "cluster_name must not be empty."
  }
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS cluster OIDC provider for IRSA"
  type        = string
}

variable "oidc_issuer" {
  description = "OIDC issuer URL without https:// prefix (e.g. oidc.eks.region.amazonaws.com/id/XXXX)"
  type        = string
}

variable "service_account_namespace" {
  description = "Kubernetes namespace of the gateway-api-controller service account"
  type        = string
  default     = "aws-application-networking-system"
}

variable "service_account_name" {
  description = "Kubernetes service account name for the gateway-api-controller"
  type        = string
  default     = "gateway-api-controller"
}

variable "tags" {
  description = "Additional tags to apply to created resources"
  type        = map(string)
  default     = {}
}
