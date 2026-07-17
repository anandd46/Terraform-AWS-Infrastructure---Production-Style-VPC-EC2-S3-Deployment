###############################################################################
# Terraform Outputs
#
# Outputs expose key resource attributes after `terraform apply` completes.
# They serve multiple purposes:
#   1. Human-readable summary of what was deployed
#   2. Input for downstream Terraform configurations (remote state data source)
#   3. Values consumed by CI/CD pipelines (e.g., EC2 IP for integration tests)
#   4. Debugging and validation during development
#
# Sensitive outputs are marked sensitive = true so Terraform masks them
# in plan/apply output. They can still be retrieved with:
#   terraform output -raw <name>
#
# Author: Anand D
###############################################################################

###############################################################################
# Account & Region
###############################################################################

output "aws_account_id" {
  description = "AWS Account ID where resources are deployed."
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS region used for this deployment."
  value       = data.aws_region.current.name
}

###############################################################################
# VPC & Networking
###############################################################################

output "vpc_id" {
  description = "ID of the VPC created by this configuration."
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.main.cidr_block
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway attached to the VPC."
  value       = aws_internet_gateway.main.id
}

output "public_subnet_id" {
  description = "ID of the public subnet."
  value       = aws_subnet.public.id
}

output "public_subnet_cidr" {
  description = "CIDR block of the public subnet."
  value       = aws_subnet.public.cidr_block
}

output "public_route_table_id" {
  description = "ID of the public route table."
  value       = aws_route_table.public.id
}

output "network_acl_id" {
  description = "ID of the Network ACL applied to the public subnet."
  value       = aws_network_acl.public.id
}

###############################################################################
# Security
###############################################################################

output "security_group_id" {
  description = "ID of the EC2 security group."
  value       = aws_security_group.ec2.id
}

output "security_group_name" {
  description = "Name of the EC2 security group."
  value       = aws_security_group.ec2.name
}

###############################################################################
# EC2
###############################################################################

output "ec2_instance_id" {
  description = "ID of the EC2 instance."
  value       = aws_instance.main.id
}

output "ec2_instance_arn" {
  description = "ARN of the EC2 instance."
  value       = aws_instance.main.arn
}

output "ec2_private_ip" {
  description = "Private IP address of the EC2 instance."
  value       = aws_instance.main.private_ip
}

output "ec2_public_ip" {
  description = "Elastic IP (public) address of the EC2 instance."
  value       = aws_eip.main.public_ip
}

output "ec2_public_dns" {
  description = "Public DNS name of the Elastic IP."
  value       = aws_eip.main.public_dns
}

output "ec2_ami_used" {
  description = "AMI ID used to launch the EC2 instance."
  value       = aws_instance.main.ami
}

output "ec2_availability_zone" {
  description = "Availability Zone where the EC2 instance is running."
  value       = aws_instance.main.availability_zone
}

output "webpage_url" {
  description = "URL of the Apache demo webpage running on the EC2 instance."
  value       = "http://${aws_eip.main.public_ip}"
}

output "ssh_command" {
  description = "SSH command to connect to the EC2 instance (after saving the private key)."
  value       = "ssh -i ${local.ssh_key_name}.pem ec2-user@${aws_eip.main.public_ip}"
}

###############################################################################
# SSH Key
###############################################################################

output "ssh_private_key_pem" {
  description = "PEM-encoded private SSH key. Save to a file and chmod 400 before use."
  value       = tls_private_key.ssh_key.private_key_pem
  sensitive   = true
}

output "key_pair_name" {
  description = "Name of the AWS Key Pair created for SSH access."
  value       = aws_key_pair.main.key_name
}

###############################################################################
# S3
###############################################################################

output "s3_bucket_name" {
  description = "Name of the S3 bucket."
  value       = aws_s3_bucket.main.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket."
  value       = aws_s3_bucket.main.arn
}

output "s3_bucket_domain_name" {
  description = "Regional domain name of the S3 bucket."
  value       = aws_s3_bucket.main.bucket_regional_domain_name
}

###############################################################################
# IAM
###############################################################################

output "iam_role_name" {
  description = "Name of the IAM role attached to the EC2 instance."
  value       = aws_iam_role.ec2_role.name
}

output "iam_role_arn" {
  description = "ARN of the IAM role attached to the EC2 instance."
  value       = aws_iam_role.ec2_role.arn
}

output "iam_instance_profile_name" {
  description = "Name of the IAM instance profile."
  value       = aws_iam_instance_profile.ec2_profile.name
}

output "iam_policy_arn" {
  description = "ARN of the custom IAM policy attached to the role."
  value       = aws_iam_policy.ec2_policy.arn
}

output "iam_user_name" {
  description = "Name of the demo IAM user."
  value       = aws_iam_user.demo_user.name
}

output "iam_user_arn" {
  description = "ARN of the demo IAM user."
  value       = aws_iam_user.demo_user.arn
}

###############################################################################
# CloudWatch
###############################################################################

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch Log Group for application logs."
  value       = aws_cloudwatch_log_group.application.name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch Log Group."
  value       = aws_cloudwatch_log_group.application.arn
}

###############################################################################
# Deployment Summary
###############################################################################

output "deployment_summary" {
  description = "Summary of key deployment details."
  value = {
    project_name      = var.project_name
    environment       = var.environment
    region            = var.aws_region
    vpc_id            = aws_vpc.main.id
    ec2_id            = aws_instance.main.id
    ec2_public_ip     = aws_eip.main.public_ip
    s3_bucket         = aws_s3_bucket.main.id
    log_group         = aws_cloudwatch_log_group.application.name
    webpage           = "http://${aws_eip.main.public_ip}"
  }
}
