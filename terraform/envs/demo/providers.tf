terraform {
  required_version = ">= 1.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
  }

  # Local backend — no remote state dependency.
  # To use S3 backend, replace this block:
  #   backend "s3" {
  #     bucket = "<your-bucket>"
  #     key    = "eks-sidecarless-service-networking/envs/demo/terraform.state"
  #     region = "<your-region>"
  #   }
}

provider "aws" {
  region = var.region
}

