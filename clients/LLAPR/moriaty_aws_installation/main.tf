# Key Pair for EC2 instances
resource "aws_key_pair" "ssh_key" {
  key_name   = "drupal-key"
  public_key = file("~/.ssh/id_rsa.pub")
}


# Security Group for EC2 instances
resource "aws_security_group" "moriarty_ec2_sg" {
  name_prefix = "drupal-ec2-sg"
    vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict to your EC2/RDS communication range
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Launch EC2 Instances
resource "aws_instance" "moriarty_runtime" {
  count         = var.number_of_instances
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = aws_key_pair.ssh_key.key_name
  security_groups = [aws_security_group.moriarty_ec2_sg.id]
  iam_instance_profile = aws_iam_instance_profile.developer_portal_instance_profile.name
  depends_on = [aws_instance.importer_instance, null_resource.wait_for_importer]
  subnet_id  = var.private_subnet
  associate_public_ip_address = false

  user_data = <<-EOT
    #!/bin/bash
    set -e  # Exit immediately if a command exits with a non-zero status
    LOG_FILE=/var/log/startup-script.log
    exec > >(tee -a $LOG_FILE ) 2>&1

    echo "Script started on $(date)"
    # Set HOME for the script
    export HOME=/home/ec2-user  # Set this to the appropriate home directory, e.g., `/home/ec2-user` for Amazon Linux

    echo "Runtime Variable Configure"
    # Variables from Terraform
    GIT_REPO="${var.git_repo}"
    DEST_DIR="${var.dest_dir}"
    BRANCH="${var.branch}"
    DB_NAME="${var.database_name}"
    DB_USER="${aws_db_instance.moriarty.username}"
    DB_PASSWORD="${aws_db_instance.moriarty.password}"
    DB_HOST="${aws_db_instance.moriarty.address}"

    echo $DB_NAME
    echo $DB_USER
    echo $DB_PASSWORD
    echo $DB_HOST

    # Disable SELinux
    setenforce 0
    # sed -i 's/SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
    

    
    echo "Ensure /var/log directory with 0755 permission"
    mkdir -p /var/log


    echo "Update and install packages"
    sudo yum update -y

    echo "Install Required Packages"
    sudo yum install -y \
          wget \
          git \
          zip \
          composer \
          nginx \
          php8.2 \
          php-cli \
          php-fpm \
          php-json \
          php-mysqlnd \
          php-zip \
          php-gd \
          php-intl \
          php-mbstring \
          php-curl \
          php-xml \
          php-pear \
          php-soap \
          php-bcmath \
          php-dba \
          php-dbg \
          php-devel \
          php-common \
          php-embedded \
          php-enchant \
          php-gmp \
          php-ldap \
          php-odbc \
          php-pdo \
          php-opcache \
          php-process \
          php-snmp \
          patch \
          jq

    echo "Install Supervisor Via python"
    sudo dnf install -y python3-pip
    sudo pip3 install supervisor


    echo "Check if the Git Repository Already Exists:"
      if [ -d /var/www/html/shushportal ]; then
      echo "Repository directory exists."
    else
      echo "Repository directory does not exist. Creating it now..."
      mkdir -p /var/www/html/shushportal
      echo "Repository directory created."
    fi

    # Mark the directory as safe for Git
    git config --global --add safe.directory /var/www/html/shushportal
    echo "Marked /var/www/html/shushportal as a safe Git directory."

    # Check if the repository directory exists
    if [ -d "$DEST_DIR/.git" ]; then
      echo "Git repository already exists. Ensuring the branch is checked out and up-to-date..."
      cd "$DEST_DIR"
      git fetch origin
      git checkout "$BRANCH"
      git pull origin "$BRANCH"
    else
      echo "Git repository does not exist. Cloning the repository..."
      echo "Git repository: $GIT_REPO"
      echo "Destination directory: $DEST_DIR"
      echo "Branch: $BRANCH"
      git clone --branch "$BRANCH" "$GIT_REPO" "$DEST_DIR"
    fi

    # Ensure Nginx sites-enabled directory exists
    mkdir -p /etc/nginx/sites-enabled
    chmod 0755 /etc/nginx/sites-enabled
    echo "/etc/nginx/sites-enabled directory ensured with 0755 permissions."

    mkdir -p /var/www/html/shushportal/scripts
    chmod 0755 /var/www/html/shushportal/scripts
    echo "/var/www/html/shushportal/scripts directory ensured with 0755 permissions."

    mkdir -p /var/www/html/shushportal/private-files
    chmod 0755 /var/www/html/shushportal/private-files
    echo "/var/www/html/shushportal/private-files directory ensured with 0755 permissions."

    # Define project directory
    PROJECT_DIR="/var/www/html/shushportal"

    echo "change to portal folder"
    cd /var/www/html/shushportal

    echo "Set Composer environment variables"
    export COMPOSER_ALLOW_SUPERUSER=1
    export COMPOSER_MEMORY_LIMIT=2G

    echo "Persist COMPOSER_HOME to the user's profile"
    echo "export COMPOSER_HOME=/usr/bin/composer" >> ~/.profile
    source ~/.profile

    echo " Install Composer dependencies"
    if command -v composer >/dev/null 2>&1; then
      /usr/bin/composer install --no-interaction
      echo "Composer dependencies installed successfully."
    else
      echo "Composer not installed. Please ensure Composer is available."
    fi

     # Ensure destination directory exists
    mkdir -p /var/www/html/shushportal/web/sites/default

    # Define S3 bucket and file keys
    S3_BUCKET="${aws_s3_bucket.db_dump_bucket.id}"
    DRUPAL_NGINX_CONF="drupal-nginx.conf"
    NGINX_CONF="nginx.conf"
    SALT="salt.txt"
    SETTINGS="settings.php"

    echo "remove default nginx.conf"
    mv  /etc/nginx/nginx.conf  /etc/nginx/.nginx.conf_beforeInstallation.
    echo "Downloading Nginx configuration files from S3..."
    aws s3 cp s3://$S3_BUCKET/$DRUPAL_NGINX_CONF /etc/nginx/sites-enabled/drupal-nginx.conf
    aws s3 cp s3://$S3_BUCKET/$NGINX_CONF /etc/nginx/nginx.conf
    aws s3 cp s3://$S3_BUCKET/$SALT  /var/www/html/shushportal/private-files/salt.txt
    aws s3 cp s3://$S3_BUCKET/$SETTINGS  /var/www/html/shushportal/web/sites/default/settings.php

    echo "setting.php changes"
    echo "Copy settings.php and replace placeholders"
    sed -i "s/{{ db_name }}/$DB_NAME/" /var/www/html/shushportal/web/sites/default/settings.php
    sed -i "s/{{ db_user }}/$DB_USER/" /var/www/html/shushportal/web/sites/default/settings.php
    sed -i "s/{{ db_password }}/$DB_PASSWORD/" /var/www/html/shushportal/web/sites/default/settings.php
    sed -i "s/{{ db_host }}/$DB_HOST/" /var/www/html/shushportal/web/sites/default/settings.php
    echo "settings.php configured successfully."
   
     # Create devportal group
    if ! getent group devportal >/dev/null; then
        groupadd --system devportal
        echo "devportal group created successfully."
    else
        echo "devportal group already exists."
    fi

    # Create devportal user
    if ! id -u devportal >/dev/null 2>&1; then
        useradd --system --create-home --home-dir /home/devportal --shell /bin/bash --gid devportal devportal
        echo "devportal user created successfully."
    else
        echo "devportal user already exists."
    fi

    # Change ownership of /var/www/html
    echo "Changing ownership of /var/www/html to devportal:nginx..."
    chown -R devportal:nginx /var/www/html
    chmod -R 0755 /var/www/html
    echo "Ownership and permissions updated for /var/www/html."

    # Restart PHP-FPM service
    echo "Restarting PHP-FPM to apply changes..."
    systemctl restart php-fpm
    if [ $? -eq 0 ]; then
        echo "PHP-FPM restarted successfully."
    else
        echo "Failed to restart PHP-FPM service."
    fi

    # Reload Nginx service
    echo "Reloading Nginx to apply configuration changes..."
    sudo systemctl start nginx
    systemctl reload nginx
    if [ $? -eq 0 ]; then
        echo "Nginx reloaded successfully."
    else
        echo "Failed to reload Nginx service."
    fi

    echo "DB Updates"
    echo "Clear Cache"
    /var/www/html/shushportal/vendor/bin/drush cr
    echo "Import configuration"
    /var/www/html/shushportal/vendor/bin/drush cim -y
    # echo "Enable zcs_apis module"
    # /var/www/html/shushportal/vendor/bin/drush en zcs_apis -y
    # echo "Enable shush theme"
    # /var/www/html/shushportal/vendor/bin/drush theme:en shush -y
    # echo "Set default theme"
    # /var/www/html/shushportal/vendor/bin/drush config-set system.theme default shush -y
    # echo "Enable zcs_user_management module"
    # /var/www/html/shushportal/vendor/bin/drush en zcs_user_management -y
    # echo " Enable zcs_client_management module"
    # /var/www/html/shushportal/vendor/bin/drush en zcs_client_management -y
    echo "Enable zcs_kong module"
    /var/www/html/shushportal/vendor/bin/drush en zcs_kong -y
    echo "DisAble zcs_kong module"
    /var/www/html/shushportal/vendor/bin/drush pmu zcs_kong -y
    echo "Enable zcs_aws module"
    /var/www/html/shushportal/vendor/bin/drush en zcs_aws -y
    # echo "Enable zcs_custom module"
    # /var/www/html/shushportal/vendor/bin/drush en zcs_custom -y
    echo " Run database updates"
    /var/www/html/shushportal/vendor/bin/drush updb
    echo "Cache Clear"
    /var/www/html/shushportal/vendor/bin/drush cr


    # Change PHP-FPM user and group to nginx
    echo "Changing PHP-FPM user and group to nginx..."
    sed -i -e 's/^user = apache/user = nginx/' -e 's/^group = apache/group = nginx/' /etc/php-fpm.d/www.conf
    echo "PHP-FPM user and group updated successfully to nginx."

    # Restart PHP-FPM service
    echo "Restarting PHP-FPM to apply changes..."
    systemctl restart php-fpm
    if [ $? -eq 0 ]; then
        echo "PHP-FPM restarted successfully."
    else
        echo "Failed to restart PHP-FPM service."
    fi

    # Reload Nginx service
    echo "Reloading Nginx to apply configuration changes..."
    sudo systemctl start nginx
    systemctl reload nginx
    if [ $? -eq 0 ]; then
        echo "Nginx reloaded successfully."
    else
        echo "Failed to reload Nginx service."
    fi


    # Write a completion marker
    echo "User data script completed" > /tmp/user_data_complete

    echo "Startup script completed successfully."
  EOT

  tags = {
    Name = "drupal-instance-${count.index + 1}"
  }
}


# S3 Bucket for Database Dumps
resource "aws_s3_bucket" "db_dump_bucket" {
  bucket        = "${var.bucket_name}-${random_id.bucket.hex}"
  force_destroy = true
}

# resource "aws_s3_bucket_acl" "db_dump_bucket_acl" {
#   bucket = aws_s3_bucket.db_dump_bucket.id
#   acl    = "private"
# }

#Add a bucket policy to allow appropriate access

# IAM Role for Developer Portal
resource "aws_iam_role" "developer_portal" {
  name = "DeveloperPortal"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement: [
      {
        Effect: "Allow",
        Principal: {
          Service: "ec2.amazonaws.com"
        },
        Action: "sts:AssumeRole"
      }
    ]
  })
}

# IAM Policy for Developer Portal
resource "aws_iam_policy" "developer_portal_policy" {
  name        = "DeveloperPortalPolicy"
  description = "Policy for Developer Portal to manage S3, RDS, and EC2"

  policy = jsonencode({
    Version: "2012-10-17",
    Statement: [
      {
        Effect: "Allow",
        Action: [
          "ec2:DescribeInstances",
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:TerminateInstances",
          "ec2:CreateTags"
        ],
        Resource: "*"
      },
      {
        Effect: "Allow",
        Action: [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ],
        Resource: [
          "${aws_s3_bucket.db_dump_bucket.arn}",
          "${aws_s3_bucket.db_dump_bucket.arn}/*"
        ]
      },
      {
        Effect: "Allow",
        Action: [
          "rds:DescribeDBInstances",
          "rds:CreateDBInstance",
          "rds:DeleteDBInstance",
          "rds:ModifyDBInstance",
          "rds:StartDBInstance",
          "rds:StopDBInstance"
        ],
        Resource: "*"
      }
    ]
  })
}

#Add a bucket policy to allow appropriate access
# resource "aws_s3_bucket_policy" "db_dump_bucket_policy" {
#   bucket = aws_s3_bucket.db_dump_bucket.id

#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect = "Allow",
#         Principal = "*",
#         Action = [
#           "s3:GetObject",
#           "s3:PutObject"
#         ],
#         Resource = "${aws_s3_bucket.db_dump_bucket.arn}/*"
#       }
#     ]
#   })
# }


# Attach Policy to Role
resource "aws_iam_role_policy_attachment" "developer_portal_policy_attachment" {
  role       = aws_iam_role.developer_portal.name
  policy_arn = aws_iam_policy.developer_portal_policy.arn
}

# Instance Profile for EC2
resource "aws_iam_instance_profile" "developer_portal_instance_profile" {
  name = "DeveloperPortalInstanceProfile"
  role = aws_iam_role.developer_portal.name
}



# RDS MySQL Instance
resource "aws_db_instance" "moriarty" {
  identifier              = var.database_name
  allocated_storage       = 50
  engine                  = "mysql"
  engine_version          = var.database_version
  instance_class          = "db.t3.xlarge"
  username                = var.database_user
  password                = var.database_password
  publicly_accessible     = true
  vpc_security_group_ids  = [aws_security_group.moriarty_ec2_sg.id]
  skip_final_snapshot     = true
  db_subnet_group_name    = aws_db_subnet_group.moriarty_subnet_group.name
  #name                    = var.database_name # Add the DB name
}

# RDS Subnet Group
resource "aws_db_subnet_group" "moriarty_subnet_group" {
  name        = "moriarty-subnet-group"
  description = "Subnet group for RDS"
  subnet_ids  = var.private_subnets
}

resource "aws_s3_object" "db_dump" {
  bucket = aws_s3_bucket.db_dump_bucket.id
  key    = "zcs_new.sql"
  source = "./portalasserts/zcs_new.sql" # Path to the dump file on your local machine
  acl    = "private"
}

resource "aws_s3_object" "drupal_nginx_conf" {
  bucket = aws_s3_bucket.db_dump_bucket.id
  key    = "drupal-nginx.conf"
  source = "./portalasserts/drupal-nginx.conf"
  acl    = "private"
}

resource "aws_s3_object" "nginx_conf" {
  bucket = aws_s3_bucket.db_dump_bucket.id
  key    = "nginx.conf"
  source = "./portalasserts/nginx.conf"
  acl    = "private"
}

resource "aws_s3_object" "salt" {
  bucket = aws_s3_bucket.db_dump_bucket.id
  key    = "salt.txt"
  source = "./portalasserts/salt.txt"
  acl    = "private"
}
resource "aws_s3_object" "settings" {
  bucket = aws_s3_bucket.db_dump_bucket.id
  key    = "settings.php"
  source = "./portalasserts/settings.php"
  acl    = "private"
}



# EC2 Instance
resource "aws_instance" "importer_instance" {
  ami           = var.importer_instances_ami_id                   # Amazon Linux 2 or compatible image
  instance_type = "t3.medium"
  key_name      = aws_key_pair.ssh_key.key_name
  vpc_security_group_ids = [aws_security_group.moriarty_ec2_sg.id]
  iam_instance_profile = aws_iam_instance_profile.developer_portal_instance_profile.name
  subnet_id = var.public_subnet
  associate_public_ip_address = true
  depends_on =[
    aws_db_instance.moriarty,
    aws_security_group.moriarty_ec2_sg
  ]

  user_data = <<-EOT
    #!/bin/bash
    set -e

    LOG_FILE="/var/log/sql_import.log"
    exec > >(tee -a $LOG_FILE) 2>&1

    echo "Script started on $(date)"

    echo "Updating packages..."
    sudo yum update -y

    echo "Installing MySQL client..."
    sudo yum install mysql -y

    echo "Downloading SQL dump from S3..."
    aws s3 cp s3://${aws_s3_bucket.db_dump_bucket.id}/zcs_new.sql /tmp/zcs_new.sql


    echo "Importing SQL dump into the database..."
    export MYSQL_PWD=${aws_db_instance.moriarty.password}
    echo $MYSQL_PWD
    # echo ${aws_db_instance.moriarty.endpoint}
    # echo ${aws_db_instance.moriarty.username}
    # echo ${var.database_name}
    # echo ${aws_db_instance.moriarty.address}
    
    mysql -h ${aws_db_instance.moriarty.address} \
          -u ${aws_db_instance.moriarty.username} \
          -p${aws_db_instance.moriarty.password} \
          -e "CREATE DATABASE IF NOT EXISTS ${var.database_name};"

    mysql -h ${aws_db_instance.moriarty.address} \
          -u ${aws_db_instance.moriarty.username} \
          -p${aws_db_instance.moriarty.password} \
          ${var.database_name} < /tmp/zcs_new.sql

    echo "SQL dump import completed!"
    # Write a completion marker
    echo "User data script completed" > /tmp/user_data_complete
    echo "Script completed on $(date)"
  EOT

  tags = {
    Name = "sql-import-instance"
  }
}

resource "null_resource" "wait_for_importer" {
  depends_on = [aws_instance.importer_instance]

  provisioner "remote-exec" {
    inline = [
      "while [ ! -f /tmp/user_data_complete ]; do echo 'Waiting for importer script...'; sleep 10; done",
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user" # Update based on your AMI
      private_key = file("~/.ssh/id_rsa")
      host        = aws_instance.importer_instance.public_ip
      timeout     = "10m"
    }
  }
  
}


# Random ID for S3 bucket naming
resource "random_id" "bucket" {
  byte_length = 2
}

#Create a Load Balancer
resource "aws_lb" "application_lb" {
  name               = "moriarty-application-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.moriarty_ec2_sg.id]
  subnets            = var.public_subnets
  enable_deletion_protection = true
  depends_on = [aws_instance.moriarty_runtime]
  

  tags = {
    Name = "moriarty-Application-LB"
  }
}

#Create a Target Group
resource "aws_lb_target_group" "application_tg" {
  name        = "drupal-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id  # Your VPC ID

  health_check {
    path                = "/health-check"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = {
    Name = "Drupal-Target-Group"
  }
}

#Attach EC2 Instances to the Target Group
resource "aws_lb_target_group_attachment" "application_tg_attachment" {
  count            = var.number_of_instances
  target_group_arn = aws_lb_target_group.application_tg.arn
  target_id        = aws_instance.moriarty_runtime[count.index].id
  port             = 80
}

# Create a Listener for the Load Balancer
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.application_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.application_tg.arn
  }
}

# Add an ingress rule to allow traffic on port 80 from all IPs (0.0.0.0/0) for the load balancer security group.

resource "aws_security_group" "lb_sg" {
  name        = "drupal-lb-sg"
  description = "Security group for the Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
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

# Create access key for the IAM user
resource "aws_iam_access_key" "sherlock_auth_user_access_key" {
  user = aws_iam_user.sherlock_auth_user.name
}

# Output the access key ID and secret access key (optional, be cautious with this)
output "sherlock_auth_user_access_key_id" {
  value = aws_iam_access_key.sherlock_auth_user_access_key.id
  sensitive = true
}

output "sherlock_auth_user_secret_access_key" {
  value = aws_iam_access_key.sherlock_auth_user_access_key.secret
  sensitive =  true
}