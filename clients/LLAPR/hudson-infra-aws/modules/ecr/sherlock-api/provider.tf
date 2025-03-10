terraform {
  required_version = ">= 1.3.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.75"
    }
  }

  backend "s3" {
    bucket         = "shush-terraform-state"
    key            = "ecr/sherlock-api/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "tf_lock"
  }
}

provider "aws" {
  region = "us-east-1"
}

