############################################
# variables.tf
# All configurable input variables for the project
############################################

variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g. dev, staging, production)"
  type        = string
  default     = "production"
}

variable "owner" {
  description = "Owner tag applied to all resources"
  type        = string
  default     = "cloud-engineering-team"
}

variable "project_name" {
  description = "Project name used as a prefix for resource naming"
  type        = string
  default     = "production-style-vpc"
}

# -------------------------------------------------------------
# NETWORKING
# -------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of Availability Zones to deploy subnets into (must be 2 for this architecture)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "enable_nat_gateway" {
  description = "Whether to deploy a managed NAT Gateway (NOT Free Tier eligible). Set to false to skip NAT Gateway creation and rely on the Free Tier alternative described in the README (NAT Instance or no outbound internet from private subnet)."
  type        = bool
  default     = true
}

variable "enable_nat_instance" {
  description = "Whether to deploy a Free-Tier-eligible t2.micro/t3.micro NAT Instance instead of a managed NAT Gateway. Only used when enable_nat_gateway = false."
  type        = bool
  default     = false
}

# -------------------------------------------------------------
# COMPUTE
# -------------------------------------------------------------

variable "instance_type" {
  description = "EC2 instance type used for Bastion, Public, and Private instances (Free Tier eligible)"
  type        = string
  default     = "t2.micro"
}

variable "nat_instance_type" {
  description = "EC2 instance type used for the optional NAT Instance"
  type        = string
  default     = "t2.micro"
}

variable "key_pair_name" {
  description = "Name of an existing EC2 Key Pair used for SSH access to instances. Create this in the AWS Console (EC2 > Key Pairs) or via `aws ec2 create-key-pair` before applying."
  type        = string
  default     = "production-vpc-keypair"
}

variable "ami_id" {
  description = "AMI ID to use for EC2 instances. Defaults to null, in which case the latest Amazon Linux 2023 AMI is looked up automatically via a data source."
  type        = string
  default     = null
}

# -------------------------------------------------------------
# SECURITY
# -------------------------------------------------------------

variable "admin_ip_cidr" {
  description = "Your local machine's public IP address in CIDR notation (e.g. 203.0.113.10/32). Used to restrict SSH access to the Bastion Host. Find yours at https://checkip.amazonaws.com"
  type        = string
  default     = "0.0.0.0/0" # WARNING: change this before applying in production
}

variable "allowed_web_ports" {
  description = "List of ports allowed inbound on the public web security group"
  type        = list(number)
  default     = [80, 443]
}

# -------------------------------------------------------------
# TAGGING
# -------------------------------------------------------------

variable "common_tags" {
  description = "Common tags applied to all taggable resources"
  type        = map(string)
  default = {
    Project   = "Production-Style-AWS-VPC"
    ManagedBy = "Terraform"
  }
}
