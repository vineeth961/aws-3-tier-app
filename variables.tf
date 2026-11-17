variable "aws_region" {
  description = "AWS region for TaskFlow infrastructure"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name used for resource tags"
  type        = string
  default     = "taskflow"
}

variable "vpc_cidr" {
  description = "CIDR block for TaskFlow VPC"
  type        = string
  default     = "10.0.0.0/16"
}
