
###############################################################################
# Main Configuration
#
# This file contains:
#   - Data sources (read-only lookups from AWS)
#   - Random resource generation
#   - Glue resources that tie other files together
#
# Author: Anand D
###############################################################################

###############################################################################
# Data Sources
###############################################################################

# Discover the latest Amazon Linux 2023 AMI published by AWS.
# Using a data source instead of hardcoding an AMI ID means the deployment
# automatically picks up the most recent, patched image — no manual updates
# required. The filters target the official AWS-managed AMI.
data "aws_ami" "amazon_linux_2023" {
  most_recent = true

  # The owner "amazon" ensures we only get official AWS AMIs,
  # not community-published images which could be tampered with.
  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Retrieve the current AWS caller identity.
# Used to construct IAM ARNs and include the account ID in outputs
# without ever hardcoding it.
data "aws_caller_identity" "current" {}

# Retrieve metadata about the configured AWS region.
# Useful for constructing region-specific resource ARNs in policies.
data "aws_region" "current" {}

###############################################################################
# Random Resource Naming
###############################################################################

# Generate a random hex suffix for globally-unique resource names.
# The byte_length of 4 gives us an 8-character hex string (e.g., "a3f2b1c0"),
# which is long enough to prevent collisions while remaining readable.
resource "random_id" "suffix" {
  byte_length = 4
}

# Generate a random password for the IAM demo user.
# In a real environment this would never be output in plaintext —
# it is shown here purely for demonstration purposes.
resource "random_password" "iam_user_password" {
  length           = 16
  special          = true
  override_special = "!#$%^&*()-_=+[]{}?"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}
