module "ecr" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "~> 2.2.1"

  repository_name                 = "bss"
  repository_read_access_arns     = ["arn:aws:iam::537124973831:root"]
  repository_image_tag_mutability = "MUTABLE"

  create_lifecycle_policy = true
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 5 images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["latest"],
          countType     = "imageCountMoreThan",
          countNumber   = 5
        },
        action = {
          type = "expire"
        }
      }
    ]
  })

  tags = {
    is_terraform = "yes"
    environment  = "sandbox"
  }
}