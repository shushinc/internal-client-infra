variable "aws_region" {
  description = "The AWS region where the moriarty will be deployed."
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the instance"
  type        = string
  default     = "ami-0df8c184d5f6ae949" # AmazonLinux
}



variable "importer_instances_ami_id" {
  description = "AMI ID for the instance"
  type        = string
  default     = "ami-0ff8a91507f77f867" # Replace with a Drupal-compatible AMI
}

variable "instance_type" {
  description = "Instance type for EC2"
  type        = string
  default     = "t2.medium"
}

variable "number_of_instances" {
  description = "Number of EC2 instances"
  type        = number
  default     = 2
}

variable "bucket_name" {
  description = "Name for the S3 bucket"
  type        = string
  default     = "drupal-dump"
}

variable "database_version" {
  description = "MySQL version"
  type        = string
  default     = "8.0"
}

variable "database_user" {
  description = "MySQL database username"
  type        = string
  default     = "devportal"
}

variable "database_password" {
  description = "MySQL database password"
  type        = string
  default     = "securepassword"
}

variable "database_name" {
  description = "The name of the database to create."
  type        = string
  default     = "moriarty"
}

variable "git_repo" {
  description = "Shush Repo to Clone"
  type        = string
  default     = "https://github.com/shushinc/shushportal.git"
}

variable "dest_dir" {
  description = "The destination directory for the repository"
  type        = string
  default     = "/var/www/html/shushportal"
}

variable "branch" {
  description = "The branch to checkout"
  type        = string
  default     = "aws"
}

variable "vpc_id" {
  description = "vpc_id"
  type        = string
}

variable "public_subnets" {
  description = "public_subnets"
  type        = list(string)
}

variable "public_subnet" {
  description = "public_subnets="
  type        = string
  default     = "subnet-0c45f007fddcb37ee"
}

variable "private_subnets" {
  description = "private_subnets"
  type        = list
  default     = ["subnet-057cee51588896623", "subnet-0367fddfe5612a87a", "subnet-09da3ec09218374ff"]
}

variable "private_subnet" {
  description = "private_subnet"
  type        = string
  default     = "subnet-057cee51588896623"
}
