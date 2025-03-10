terraform {
  required_version = ">= 1.3.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.75"
    }
  }

  backend "s3" {
    bucket       = "prod-llapr-terraform-state"
    key          = "apigateway/terraform.tfstate"
    region       = "us-east-1" # Ensure this matches the bucket and table region
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region
}
