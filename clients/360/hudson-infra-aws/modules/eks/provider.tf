terraform {
  required_version = ">= 1.3.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.75"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.16.0"
    }
  }

  backend "s3" {
    bucket       = "prod-360-terraform-state"
    key          = "eks/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region
}

