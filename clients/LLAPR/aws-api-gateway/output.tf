output "cognito_app_client_id" {
  value = aws_cognito_user_pool_client.sherlock_app_client.id
  description = "The ID of the Cognito App Client"
}

output "cognito_app_client_secret" {
  value       = aws_cognito_user_pool_client.sherlock_app_client.client_secret
  description = "The Client Secret of the Cognito App Client"
  sensitive   = true
}

output "cognito_user_pool_endpoint" {
  value       = "https://${aws_cognito_user_pool_domain.sherlock_userpool_domain.domain}.auth.${var.aws_region}.amazoncognito.com"
  description = "Oauth Endpoint"
}
output "api_endpoint" {
  description = "Shush API Gateway Endpoint"
  value       = "https://${aws_api_gateway_rest_api.sherlock.id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_stage.sherlock.stage_name}"
}
