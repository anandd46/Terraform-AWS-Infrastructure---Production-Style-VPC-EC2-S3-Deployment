###############################################################################
# Terraform Variable Definitions
#
# This file supplies concrete values for the variables declared in variables.tf.
# It is committed to the repository because it contains no secrets — only
# configuration choices specific to this environment.
#
# For secrets (API keys, passwords), use environment variables (TF_VAR_*)
# or AWS Secrets Manager, never this file.
#
# Author: Anand D
###############################################################################

# ── Global ──────────────────────────────────────────────────────────────────
aws_region   = "us-east-1"
project_name = "aws-infra"
environment  = "production"
owner        = "Anand D"

# ── Networking ───────────────────────────────────────────────────────────────
# Using the RFC 1918 private range 10.0.0.0/16.
# The /16 prefix gives 65,534 usable host addresses — far more than this
# project needs, but it mirrors how real production VPCs are sized
# so there is room to add private subnets, NAT gateways, and more later.
vpc_cidr           = "10.0.0.0/16"
public_subnet_cidr = "10.0.1.0/24"
availability_zone  = "us-east-1a"

# ── Compute ──────────────────────────────────────────────────────────────────
# t3.micro is free-tier eligible (first 750 hours/month on new accounts).
# Leave ami_id empty to use the latest Amazon Linux 2023 AMI automatically.
instance_type       = "t3.micro"
ami_id              = ""
associate_public_ip = true
root_volume_size    = 20
root_volume_type    = "gp3"

# ── Security ─────────────────────────────────────────────────────────────────
# WARNING: 0.0.0.0/0 is open to the world — fine for a demo but replace
# with your actual IP (e.g. "203.0.113.42/32") before production use.
allowed_ssh_cidr  = "0.0.0.0/0"
allowed_http_cidr = "0.0.0.0/0"

# ── S3 ───────────────────────────────────────────────────────────────────────
s3_force_destroy      = false
s3_versioning_enabled = true

# ── IAM ──────────────────────────────────────────────────────────────────────
iam_user_name = "terraform-demo-user"

# ── CloudWatch ───────────────────────────────────────────────────────────────
cloudwatch_log_retention_days = 30

# ── Extra Tags ────────────────────────────────────────────────────────────────
additional_tags = {
  CostCenter  = "engineering"
  ManagedBy   = "terraform"
  Repository  = "aws-infra-terraform"
}
