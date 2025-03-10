provider "aws" {
  region = "us-east-1"
}

# IAM Role for SherlockAuthUser
resource "aws_iam_role" "sherlock_auth_role" {
  name = "SherlockAuthRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# First Policy - us-east-1 User Pool Access
resource "aws_iam_policy" "sherlock_auth_policy_1" {
  name        = "SherlockAuthPolicyEast"
  description = "Policy for accessing Cognito user pools in us-east-1"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "cognito-idp:CreateUserPoolClient",
          "cognito-idp:DescribeUserPool",
          "cognito-idp:ListUserPoolClients"
        ],
        Resource = "arn:aws:cognito-idp:us-east-1:537124973831:userpool/*"
      }
    ]
  })
}

# Second Policy - us-west-1 Specific User Pool
resource "aws_iam_policy" "sherlock_auth_policy_2" {
  name        = "SherlockAuthPolicyWest"
  description = "Policy for managing a specific Cognito user pool in us-west-1"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "cognito-idp:CreateUserPoolClient",
          "cognito-idp:DescribeUserPool",
          "cognito-idp:ListUserPoolClients",
          "cognito-idp:UpdateUserPoolClient",
          "cognito-idp:DeleteUserPoolClient"
        ],
        Resource = "arn:aws:cognito-idp:us-west-1:537124973831:userpool/us-west-1_8rBeQnnlY"
      }
    ]
  })
}

# Third Policy - Cognito & CloudWatch Logs Access
resource "aws_iam_policy" "sherlock_auth_policy_3" {
  name        = "SherlockAuthPolicyLogs"
  description = "Policy for managing Cognito and accessing CloudWatch logs"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "cognito-idp:CreateUserPoolClient",
          "cognito-idp:DescribeUserPool",
          "cognito-idp:ListUserPoolClients",
          "cognito-idp:UpdateUserPoolClient",
          "cognito-idp:DeleteUserPoolClient"
        ],
        Resource = "arn:aws:cognito-idp:us-west-1:537124973831:userpool/us-west-1_8rBeQnnlY"
      },
      {
        Effect = "Allow",
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ],
        Resource = "arn:aws:logs:us-west-1:537124973831:log-group:/aws/api-gateway/dev:*"
      }
    ]
  })
}

# Attach all three policies to the role
resource "aws_iam_role_policy_attachment" "sherlock_auth_attachment_1" {
  role       = aws_iam_role.sherlock_auth_role.name
  policy_arn = aws_iam_policy.sherlock_auth_policy_1.arn
}

resource "aws_iam_role_policy_attachment" "sherlock_auth_attachment_2" {
  role       = aws_iam_role.sherlock_auth_role.name
  policy_arn = aws_iam_policy.sherlock_auth_policy_2.arn
}

resource "aws_iam_role_policy_attachment" "sherlock_auth_attachment_3" {
  role       = aws_iam_role.sherlock_auth_role.name
  policy_arn = aws_iam_policy.sherlock_auth_policy_3.arn
}

# Create the IAM User
resource "aws_iam_user" "sherlock_auth_user" {
  name = "SherlockAuthUser"
}

# Attach the user to the role by adding it to an IAM group
resource "aws_iam_group" "sherlock_auth_group" {
  name = "SherlockAuthGroup"
}

resource "aws_iam_group_policy_attachment" "sherlock_auth_group_attach_1" {
  group      = aws_iam_group.sherlock_auth_group.name
  policy_arn = aws_iam_policy.sherlock_auth_policy_1.arn
}

resource "aws_iam_group_policy_attachment" "sherlock_auth_group_attach_2" {
  group      = aws_iam_group.sherlock_auth_group.name
  policy_arn = aws_iam_policy.sherlock_auth_policy_2.arn
}

resource "aws_iam_group_policy_attachment" "sherlock_auth_group_attach_3" {
  group      = aws_iam_group.sherlock_auth_group.name
  policy_arn = aws_iam_policy.sherlock_auth_policy_3.arn
}

# Assign the user to the group
resource "aws_iam_user_group_membership" "sherlock_auth_user_group" {
  user  = aws_iam_user.sherlock_auth_user.name
  groups = [aws_iam_group.sherlock_auth_group.name]
}

