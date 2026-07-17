###############################################################################
# Input Variables
#
# Variables make this configuration reusable across environments (dev, staging,
# production) without touching the Terraform code itself. Values are supplied
# via terraform.tfvars or environment variables (TF_VAR_*).
#
# Author: Anand D
###############################################################################

###############################################################################
# General / Global
###############################################################################

variable "aws_region" {
  description = "AWS region where all resources will be provisioned."
  type        = string
  default     = "us-east-1"

  validation {
    condition = contains([
      "us-east-1", "us-east-2", "us-west-1", "us-west-2",
      "ap-south-1", "ap-southeast-1", "ap-southeast-2",
      "eu-west-1", "eu-west-2", "eu-central-1"
    ], var.aws_region)
    error_message = "The aws_region must be a supported AWS region."
  }
}

variable "project_name" {
  description = "Project name used as a prefix for all resource names and tags."
  type        = string
  default     = "aws-infra"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.project_name))
    error_message = "project_name must be 3–20 characters, lowercase alphanumeric or hyphens only."
  }
}

variable "environment" {
  description = "Deployment environment (dev, staging, production)."
  type        = string
  default     = "production"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "environment must be one of: dev, staging, production."
  }
}

variable "owner" {
  description = "Name of the person or team who owns these resources."
  type        = string
  default     = "Anand D"
}

###############################################################################
# Networking
###############################################################################

variable "vpc_cidr" {
  description = "CIDR block for the VPC. /16 gives us 65,536 addresses — enough headroom for expansion."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid CIDR block (e.g. 10.0.0.0/16)."
  }
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet. /24 provides 256 addresses, sufficient for public-facing resources."
  type        = string
  default     = "10.0.1.0/24"

  validation {
    condition     = can(cidrnetmask(var.public_subnet_cidr))
    error_message = "public_subnet_cidr must be a valid CIDR block."
  }
}

variable "availability_zone" {
  description = "Availability Zone for the public subnet and EC2 instance."
  type        = string
  default     = "us-east-1a"
}

###############################################################################
# EC2 / Compute
###############################################################################

variable "instance_type" {
  description = "EC2 instance type. t3.micro is free-tier eligible and cost-effective for demos."
  type        = string
  default     = "t3.micro"

  validation {
    condition = contains([
      "t2.micro", "t2.small", "t2.medium",
      "t3.micro", "t3.small", "t3.medium",
      "t3a.micro", "t3a.small",
      "m5.large", "m5.xlarge"
    ], var.instance_type)
    error_message = "instance_type must be a valid and cost-reasonable EC2 instance type."
  }
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance. Leave empty to use the latest Amazon Linux 2023 AMI via data source."
  type        = string
  default     = ""
}

variable "associate_public_ip" {
  description = "Whether to assign a public IP to the EC2 instance."
  type        = bool
  default     = true
}

variable "root_volume_size" {
  description = "Size of the EC2 root EBS volume in GB."
  type        = number
  default     = 20

  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 100
    error_message = "root_volume_size must be between 8 and 100 GB."
  }
}

variable "root_volume_type" {
  description = "EBS volume type. gp3 offers better performance and lower cost than gp2."
  type        = string
  default     = "gp3"

  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2"], var.root_volume_type)
    error_message = "root_volume_type must be one of: gp2, gp3, io1, io2."
  }
}

###############################################################################
# S3
###############################################################################

variable "s3_force_destroy" {
  description = "Allow Terraform to destroy the S3 bucket even if it contains objects. Set to false in production."
  type        = bool
  default     = false
}

variable "s3_versioning_enabled" {
  description = "Enable S3 object versioning. Recommended true in production for data protection."
  type        = bool
  default     = true
}

###############################################################################
# IAM
###############################################################################

variable "iam_user_name" {
  description = "Name for the IAM user created by Terraform."
  type        = string
  default     = "terraform-demo-user"

  validation {
    condition     = can(regex("^[a-zA-Z0-9+=,.@_-]{1,64}$", var.iam_user_name))
    error_message = "iam_user_name must be a valid IAM username (1–64 valid characters)."
  }
}

###############################################################################
# CloudWatch
###############################################################################

variable "cloudwatch_log_retention_days" {
  description = "Number of days to retain CloudWatch log group entries before expiration."
  type        = number
  default     = 30

  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.cloudwatch_log_retention_days)
    error_message = "cloudwatch_log_retention_days must be an AWS-supported retention value."
  }
}

###############################################################################
# SSH
###############################################################################

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into the EC2 instance. Restrict to your IP in production."
  type        = string
  default     = "0.0.0.0/0"
}

variable "allowed_http_cidr" {
  description = "CIDR block allowed to reach port 80 on the EC2 instance."
  type        = string
  default     = "0.0.0.0/0"
}

###############################################################################
# Tags
###############################################################################

variable "additional_tags" {
  description = "Additional tags to merge with the common tag set."
  type        = map(string)
  default     = {}
}
