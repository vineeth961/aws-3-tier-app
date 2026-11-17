
# ==========================================
# TaskFlow VPC
# ==========================================

resource "aws_vpc" "taskflow" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "${var.project_name}-vpc"
    Project = var.project_name
  }
}

# ==========================================
# TaskFlow Subnets across two AZs
# ==========================================

locals {
  subnets = {
    public_az1 = {
      name                    = "public-az1"
      cidr                    = "10.0.1.0/24"
      availability_zone       = "ap-south-1a"
      map_public_ip_on_launch = true
      tier                    = "public"
    }

    public_az2 = {
      name                    = "public-az2"
      cidr                    = "10.0.2.0/24"
      availability_zone       = "ap-south-1b"
      map_public_ip_on_launch = true
      tier                    = "public"
    }

    app_az1 = {
      name                    = "private-app-az1"
      cidr                    = "10.0.11.0/24"
      availability_zone       = "ap-south-1a"
      map_public_ip_on_launch = false
      tier                    = "private-app"
    }

    app_az2 = {
      name                    = "private-app-az2"
      cidr                    = "10.0.12.0/24"
      availability_zone       = "ap-south-1b"
      map_public_ip_on_launch = false
      tier                    = "private-app"
    }

    db_az1 = {
      name                    = "private-db-az1"
      cidr                    = "10.0.21.0/24"
      availability_zone       = "ap-south-1a"
      map_public_ip_on_launch = false
      tier                    = "private-db"
    }

    db_az2 = {
      name                    = "private-db-az2"
      cidr                    = "10.0.22.0/24"
      availability_zone       = "ap-south-1b"
      map_public_ip_on_launch = false
      tier                    = "private-db"
    }
  }
}

resource "aws_subnet" "taskflow" {
  for_each = local.subnets

  vpc_id                  = aws_vpc.taskflow.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = each.value.map_public_ip_on_launch

  tags = {
    Name    = "${var.project_name}-${each.value.name}"
    Project = var.project_name
    Tier    = each.value.tier
  }
}

# ==========================================
# Internet Gateway
# ==========================================

resource "aws_internet_gateway" "taskflow" {
  vpc_id = aws_vpc.taskflow.id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}

# ==========================================
# Route Tables
# ==========================================

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.taskflow.id

  tags = {
    Name    = "${var.project_name}-public-rt"
    Project = var.project_name
    Tier    = "public"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.taskflow.id
}

resource "aws_route_table" "private_app" {
  vpc_id = aws_vpc.taskflow.id

  tags = {
    Name    = "${var.project_name}-private-app-rt"
    Project = var.project_name
    Tier    = "private-app"
  }
}

resource "aws_route_table" "private_db" {
  vpc_id = aws_vpc.taskflow.id

  tags = {
    Name    = "${var.project_name}-private-db-rt"
    Project = var.project_name
    Tier    = "private-db"
  }
}

# ==========================================
# Route Table Associations
# ==========================================

resource "aws_route_table_association" "public" {
  for_each = {
    public_az1 = aws_subnet.taskflow["public_az1"].id
    public_az2 = aws_subnet.taskflow["public_az2"].id
  }

  subnet_id      = each.value
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_app" {
  for_each = {
    app_az1 = aws_subnet.taskflow["app_az1"].id
    app_az2 = aws_subnet.taskflow["app_az2"].id
  }

  subnet_id      = each.value
  route_table_id = aws_route_table.private_app.id
}

resource "aws_route_table_association" "private_db" {
  for_each = {
    db_az1 = aws_subnet.taskflow["db_az1"].id
    db_az2 = aws_subnet.taskflow["db_az2"].id
  }

  subnet_id      = each.value
  route_table_id = aws_route_table.private_db.id
}

# ==========================================
# Security Groups
# ==========================================

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow HTTP and HTTPS traffic to TaskFlow ALB"
  vpc_id      = aws_vpc.taskflow.id

  tags = {
    Name    = "${var.project_name}-alb-sg"
    Project = var.project_name
    Tier    = "public"
  }
}

resource "aws_security_group" "backend" {
  name        = "${var.project_name}-backend-sg"
  description = "Allow API traffic from TaskFlow ALB"
  vpc_id      = aws_vpc.taskflow.id

  tags = {
    Name    = "${var.project_name}-backend-sg"
    Project = var.project_name
    Tier    = "private-app"
  }
}

resource "aws_security_group" "database" {
  name        = "${var.project_name}-database-sg"
  description = "Allow PostgreSQL traffic from TaskFlow backend"
  vpc_id      = aws_vpc.taskflow.id

  tags = {
    Name    = "${var.project_name}-database-sg"
    Project = var.project_name
    Tier    = "private-db"
  }
}

# ==========================================
# ALB Inbound Rules
# ==========================================

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTP from internet"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTPS from internet"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

# ==========================================
# ALB to Backend
# ==========================================

resource "aws_vpc_security_group_egress_rule" "alb_to_backend" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Allow ALB traffic to backend API"
  ip_protocol                  = "tcp"
  from_port                    = 3000
  to_port                      = 3000
  referenced_security_group_id = aws_security_group.backend.id
}

resource "aws_vpc_security_group_ingress_rule" "backend_from_alb" {
  security_group_id            = aws_security_group.backend.id
  description                  = "Allow API traffic only from ALB"
  ip_protocol                  = "tcp"
  from_port                    = 3000
  to_port                      = 3000
  referenced_security_group_id = aws_security_group.alb.id
}

# ==========================================
# Backend to PostgreSQL
# ==========================================

resource "aws_vpc_security_group_egress_rule" "backend_to_database" {
  security_group_id            = aws_security_group.backend.id
  description                  = "Allow PostgreSQL connections to database"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.database.id
}

resource "aws_vpc_security_group_ingress_rule" "database_from_backend" {
  security_group_id            = aws_security_group.database.id
  description                  = "Allow PostgreSQL only from backend"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.backend.id
}

# ==========================================
# EC2 IAM Role for Systems Manager
# ==========================================

resource "aws_iam_role" "ec2_ssm_role" {
  name = "${var.project_name}-ec2-ssm-role"

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

  tags = {
    Name    = "${var.project_name}-ec2-ssm-role"
    Project = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "${var.project_name}-ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm_role.name

  tags = {
    Name    = "${var.project_name}-ec2-ssm-profile"
    Project = var.project_name
  }
}


# ==========================================
# SSM VPC Endpoints
# ==========================================

resource "aws_security_group" "ssm_endpoints" {
  name        = "${var.project_name}-ssm-endpoints-sg"
  description = "Allow HTTPS from TaskFlow backend"
  vpc_id      = aws_vpc.taskflow.id

  tags = {
    Name    = "${var.project_name}-ssm-endpoints-sg"
    Project = var.project_name
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssm_from_backend" {
  security_group_id            = aws_security_group.ssm_endpoints.id
  referenced_security_group_id = aws_security_group.backend.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "HTTPS from backend EC2"
}

resource "aws_vpc_security_group_egress_rule" "backend_to_ssm" {
  security_group_id            = aws_security_group.backend.id
  referenced_security_group_id = aws_security_group.ssm_endpoints.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "HTTPS to SSM endpoints"
}



# ==========================================
# TaskFlow Backend EC2
# ==========================================

resource "aws_instance" "backend" {
  ami                    = "ami-09d8c1e69d114dbf7"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.taskflow["app_az1"].id
  vpc_security_group_ids = [aws_security_group.backend.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm_profile.name

  associate_public_ip_address = false

  root_block_device {
    volume_size           = 10
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name    = "${var.project_name}-backend"
    Project = var.project_name
    Tier    = "private-app"
  }
}

output "backend_instance_id" {
  description = "TaskFlow backend EC2 instance ID"
  value       = aws_instance.backend.id
}

output "backend_private_ip" {
  description = "Private IP address of TaskFlow backend"
  value       = aws_instance.backend.private_ip
}

# RDS subnet group - private database subnets
resource "aws_db_subnet_group" "taskflow" {
  name        = "${var.project_name}-db-subnet-group"
  description = "Private database subnets for TaskFlow RDS"

  subnet_ids = [
    aws_subnet.taskflow["db_az1"].id,
    aws_subnet.taskflow["db_az2"].id
  ]

  tags = {
    Name    = "${var.project_name}-db-subnet-group"
    Project = var.project_name
    Tier    = "private-db"
  }
}


# TaskFlow PostgreSQL RDS instance
resource "aws_db_instance" "taskflow" {
  identifier     = "${var.project_name}-postgres"
  engine         = "postgres"
  engine_version = "16.15"
  instance_class = "db.t3.micro"

  db_name  = "taskflow"
  username = "taskflow_admin"
  port     = 5432

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_subnet_group_name   = aws_db_subnet_group.taskflow.name
  vpc_security_group_ids = [aws_security_group.database.id]
  publicly_accessible    = false
  multi_az               = false

  manage_master_user_password = true

  backup_retention_period    = 1
  auto_minor_version_upgrade = true
  deletion_protection        = false
  skip_final_snapshot        = true

  tags = {
    Name    = "${var.project_name}-postgres"
    Project = var.project_name
    Tier    = "private-db"
  }
}

output "rds_endpoint" {
  description = "TaskFlow PostgreSQL RDS endpoint"
  value       = aws_db_instance.taskflow.address
}

output "rds_port" {
  description = "TaskFlow PostgreSQL port"
  value       = aws_db_instance.taskflow.port
}


# ==========================================
# Temporary TaskFlow Deployment Transfer
# ==========================================

resource "aws_s3_bucket" "deployment" {
  bucket        = "taskflow-deploy-139337687281-ap-south-1"
  force_destroy = true

  tags = {
    Name    = "${var.project_name}-deployment"
    Project = var.project_name
  }
}

resource "aws_s3_bucket_public_access_block" "deployment" {
  bucket = aws_s3_bucket.deployment.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "deployment" {
  bucket = aws_s3_bucket.deployment.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "deployment" {
  bucket = aws_s3_bucket.deployment.id

  rule {
    id     = "expire-deployment-files"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 7
    }
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.taskflow.id
  service_name      = "com.amazonaws.ap-south-1.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.private_app.id
  ]

  tags = {
    Name    = "${var.project_name}-s3-gateway"
    Project = var.project_name
  }
}

resource "aws_iam_role_policy" "ec2_deployment_s3_read" {
  name = "${var.project_name}-deployment-s3-read"
  role = aws_iam_role.ec2_ssm_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.deployment.arn}/*"
      }
    ]
  })
}

output "deployment_bucket_name" {
  value = aws_s3_bucket.deployment.bucket
}

resource "aws_vpc_security_group_egress_rule" "backend_to_s3" {
  security_group_id = aws_security_group.backend.id
  prefix_list_id    = "pl-78a54011"

  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443

  description = "Allow HTTPS access to S3 through Gateway endpoint"
}

resource "aws_iam_role_policy" "taskflow_secrets_access" {
  name = "taskflow-secrets-manager-access"
  role = aws_iam_role.ec2_ssm_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:ap-south-1:139337687281:secret:rds!db-ba40c5e3-0bfe-4527-8801-68cb2844ae5c-HzJT9U"
      }
    ]
  })
}


# ==========================================
# Application Load Balancer
# ==========================================

resource "aws_lb" "taskflow" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]

  subnets = [
    aws_subnet.taskflow["public_az1"].id,
    aws_subnet.taskflow["public_az2"].id
  ]

  enable_deletion_protection = false

  tags = {
    Name    = "${var.project_name}-alb"
    Project = var.project_name
  }
}

# ==========================================
# Backend Target Group
# ==========================================

resource "aws_lb_target_group" "backend" {
  name        = "${var.project_name}-backend-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.taskflow.id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name    = "${var.project_name}-backend-tg"
    Project = var.project_name
  }
}

# ==========================================
# Register Backend EC2
# ==========================================

resource "aws_lb_target_group_attachment" "backend" {
  target_group_arn = aws_lb_target_group.backend.arn
  target_id        = aws_instance.backend.id
  port             = 3000
}

# ==========================================
# HTTP Listener
# ==========================================

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.taskflow.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

