output "vpc_id" {
  description = "TaskFlow VPC ID"
  value       = aws_vpc.taskflow.id
}

output "vpc_cidr" {
  description = "TaskFlow VPC CIDR"
  value       = aws_vpc.taskflow.cidr_block
}

output "subnet_ids" {
  description = "TaskFlow subnet IDs"
  value = {
    for name, subnet in aws_subnet.taskflow :
    name => subnet.id
  }
}
output "security_group_ids" {
  description = "TaskFlow security group IDs"

  value = {
    alb      = aws_security_group.alb.id
    backend  = aws_security_group.backend.id
    database = aws_security_group.database.id
  }
}
output "ec2_ssm_instance_profile" {
  description = "IAM instance profile for TaskFlow backend EC2"
  value       = aws_iam_instance_profile.ec2_ssm_profile.name
}


output "alb_dns_name" {
  description = "TaskFlow Application Load Balancer DNS"
  value       = aws_lb.taskflow.dns_name
}

output "alb_target_group_arn" {
  description = "TaskFlow backend target group ARN"
  value       = aws_lb_target_group.backend.arn
}

