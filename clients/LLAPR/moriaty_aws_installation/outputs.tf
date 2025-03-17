# Output Load Balancer DNS Name
output "load_balancer_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.application_lb.dns_name
}

# Output AWS Region
output "aws_region" {
  description = "AWS region where resources are deployed"
  value       = var.aws_region
}

# Output User Pool ID (Dynamically Fetching from Cognito)
output "user_pool_id" {
  description = "The ID of the Cognito User Pool"
  value       = var.cognito_user_pool_id
}
