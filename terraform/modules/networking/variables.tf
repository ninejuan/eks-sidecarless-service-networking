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

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
