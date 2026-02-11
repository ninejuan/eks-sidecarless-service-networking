variable "repository_namespace" {
  description = "Repository namespace prefix (example: demo)"
  type        = string
}

variable "repositories" {
  description = "Service repository names"
  type        = list(string)
}

variable "scan_on_push" {
  description = "Enable image scanning on push"
  type        = bool
  default     = true
}

variable "default_image_tag_mutability" {
  description = "Default mutability for repositories"
  type        = string
  default     = "MUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.default_image_tag_mutability)
    error_message = "default_image_tag_mutability must be MUTABLE or IMMUTABLE."
  }
}

variable "image_tag_mutability_overrides" {
  description = "Per-repository mutability override map"
  type        = map(string)
  default     = {}
}

variable "untagged_image_expiration_days" {
  description = "Number of days after which untagged images expire"
  type        = number
  default     = 7
}

variable "max_image_count" {
  description = "Maximum number of images to keep"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Common tags for all ECR resources"
  type        = map(string)
  default     = {}
}
