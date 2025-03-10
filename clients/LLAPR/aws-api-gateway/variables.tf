variable "aws_region" {
  description = "The AWS region where the API Gateway will be deployed."
  type        = string
}

variable "api_name" {
  description = "The name of the API Gateway."
  type        = string
  default     = "Sherlock API"
}

variable "exported_api_file" {
  description = "Path to the OpenAPI/Swagger file to import into API Gateway."
  type        = string
}

variable "stage_name" {
  description = "The name of the stage to deploy the API Gateway."
  type        = string
  default     = "prod"
}
variable "sherlock_api_url" {
  description = "Ingress for the sherlock cluster"
  type        = string
}

variable "sherlock_api_oauth_domain" {
  description = "Sherlock API Oauth Token Domain"
  type        = string
}

variable "cognito_userpoolname" {
  description = "Sherlock API Oauth Token Domain"
  type        = string
  default = "sherlock-userpool"
}

variable "sherlock_api_client" {
  description = "Sherlock API Test Client"
  type        = string
}
variable "environment" {
  description = "Environment tag for resources"
  default     = "dev"
}

# variable "base_url" {
#   description = "Base URL for the Sherlock API Endpoint"
# }

variable "oauth_domain" {
  description = "Base URL for the Sherlock API Endpoint"
}
