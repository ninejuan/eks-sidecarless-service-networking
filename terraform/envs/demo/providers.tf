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

  backend "s3" {
    bucket = "juany-wsk-tfstate"
    key    = "eks-sidecarless-service-networking/envs/demo/terraform.state"
    region = "ap-northeast-2"
  }
}

provider "aws" {
  region = var.region
}

