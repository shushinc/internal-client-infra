terraform {
  required_version = ">= 1.3.2"

  backend "s3" {
    bucket         = "prod-llapr-terraform-state" # Use a centralized bucket for all states
    key            = "clients/llapr/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"  # Enable state locking
    encrypt        = true
  }
}
