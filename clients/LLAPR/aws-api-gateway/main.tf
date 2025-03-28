

# Create a Cognito User Pool
resource "aws_cognito_user_pool" "sherlock_userpool" {
  name = var.cognito_userpoolname

  password_policy {
    minimum_length                   = 8
    require_uppercase                = true
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7
  }

  schema {
    name                     = "email"
    attribute_data_type      = "String"
    mutable                  = true
    required                 = true
    string_attribute_constraints {
      min_length = 5
      max_length = 128
    }
  }

  schema {
    name                = "phone_number"
    attribute_data_type = "String"
    mutable             = true
    required            = false
  }

  mfa_configuration = "OFF"

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
    recovery_mechanism {
      name     = "verified_phone_number"
      priority = 2
    }
  }

  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  username_configuration {
    case_sensitive = false
  }

  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  tags = {
    Environment = var.environment
  }
  
    lifecycle {
    ignore_changes = [schema]
  }

}


# Create a Cognito User Pool Domain
resource "aws_cognito_user_pool_domain" "sherlock_userpool_domain" {
  domain      = var.oauth_domain
  user_pool_id = aws_cognito_user_pool.sherlock_userpool.id
}

# Create a Cognito User Pool Resource Server with custom scopes
resource "aws_cognito_resource_server" "sherlockapiresource" {
  user_pool_id = aws_cognito_user_pool.sherlock_userpool.id
  identifier   = "sherlockapiresource"
  name         = "Sherlock API Resource"

  scope {
    scope_name  = "read"
    scope_description = "Read access to the Sherlock API"
  }

  scope {
    scope_name  = "write"
    scope_description = "Write access to the Sherlock API"
  }
}

# Prepare the OpenAPI Specification with Cognito User Pool ARN
# data "template_file" "openapi_with_authorizer" {
#   template = file(var.exported_api_file)
#   vars = {
#     cognito_user_pool_arn = aws_cognito_user_pool.sherlock_userpool.arn
#   }
# }

# Import the API Gateway
resource "aws_api_gateway_rest_api" "sherlock" {
    depends_on = [aws_cognito_user_pool.sherlock_userpool]
    name        = "sherlock-api"
     description = "API created from Swagger definition"
#   body = file(var.exported_api_file)
#   body        = data.template_file.openapi_with_authorizer.rendered
    body        = templatefile(var.exported_api_file, {
        cognito_user_pool_arn = aws_cognito_user_pool.sherlock_userpool.arn,
        base_url              = var.sherlock_api_url

    })
}

# Deploy the API
resource "aws_api_gateway_deployment" "sherlock" {
    depends_on = [aws_cognito_user_pool.sherlock_userpool]
  rest_api_id = aws_api_gateway_rest_api.sherlock.id

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.sherlock.body))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Create an API Gateway stage
resource "aws_api_gateway_stage" "sherlock" {
  depends_on = [aws_cognito_user_pool.sherlock_userpool]
  deployment_id = aws_api_gateway_deployment.sherlock.id
  rest_api_id   = aws_api_gateway_rest_api.sherlock.id
  stage_name    = var.stage_name

  variables = {
    log_level = "INFO"
     metrics_enabled = true        # Enables CloudWatch detailed metrics
    data_trace_enabled = true     # Enables AWS X-Ray tracing
  }

  # *** enable access logs with sample format ***
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw_logs.arn

    format          = jsonencode({
      timestamp       = "$context.requestTime",
      requestId         = "$context.requestId",
      ip                = "$context.identity.sourceIp",
      requestTime       = "$context.requestTime",
      httpMethod        = "$context.httpMethod",
      resourcePath      = "$context.resourcePath",
      status            = "$context.status",
      protocol          = "$context.protocol",
      responseLength    = "$context.responseLength",
      responseLatency = "$context.responseLatency",          # Total time taken
      client_id       = "$context.authorizer.claims.client_id",
      carrierName     = "$input.json('$.carrierName')", # Extract carrierName from request body
      customerName    = "$input.json('$.customerName')", # Extract customerName from request body
      body            = "$input.body"
    })
  }
}
resource "aws_api_gateway_method_settings" "sherlock" {
  rest_api_id = aws_api_gateway_rest_api.sherlock.id
  stage_name  = aws_api_gateway_stage.sherlock.stage_name
  method_path = "*/*" # Applies to all methods in this stage

   # *** enable execution logs ***
  settings {
    metrics_enabled  = true       # Enable detailed CloudWatch metrics
    logging_level    = "INFO"     # Log INFO level messages (set to ERROR for minimal logging)
    data_trace_enabled = true     # Enable data tracing for AWS X-Ray
  }
}



resource "aws_cognito_user_pool_client" "sherlock_app_client" {
  name                            = "sherlock-app-client"
  user_pool_id                    = aws_cognito_user_pool.sherlock_userpool.id
  generate_secret                 = true
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows             = ["client_credentials"]
  allowed_oauth_scopes            = [
    "sherlockapiresource/read",
    "sherlockapiresource/write"
  ]
  supported_identity_providers    = ["COGNITO"]
  depends_on = [aws_cognito_resource_server.sherlockapiresource]
}


# Cloudwatch logs

# Create a CloudWatch log group for API Gateway
resource "aws_cloudwatch_log_group" "api_gw_logs" {
  name              = "/aws/api-gateway/${var.stage_name}"
  retention_in_days = 14 # Set log retention period
}
# Associate CloudWatch Logs role ARN with API Gateway account
resource "aws_api_gateway_account" "sherlock" {
  cloudwatch_role_arn = aws_iam_role.api_gw_logs_role.arn
  depends_on          = [aws_iam_role_policy.api_gw_logs_policy]
}


# IAM Role for API Gateway to access CloudWatch
resource "aws_iam_role" "api_gw_logs_role" {
  name = "api-gw-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "apigateway.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# IAM Policy for API Gateway logging
resource "aws_iam_role_policy" "api_gw_logs_policy" {
  name   = "api-gw-logs-policy"
  role   = aws_iam_role.api_gw_logs_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents",
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ],
        Resource = "*"
      }
    ]
  })
}




