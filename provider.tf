###############################################################################
# AWS Provider Configuration
#
# The provider block tells Terraform how to authenticate and which region
# to deploy resources into. Credentials are intentionally NOT hardcoded —
# they are sourced from environment variables or an AWS CLI profile,
# following security best practices.
#
# Author: Anand D
###############################################################################

provider "aws" {
  region = var.aws_region

  # Default tags applied to every resource created by this provider.
  # This eliminates repetitive tag blocks inside individual resource
  # definitions and ensures consistent tagging across the entire deployment.
  default_tags {
    tags = local.common_tags
  }
}

# Random provider requires no additional configuration.
provider "random" {}

# TLS provider requires no additional configuration.
provider "tls" {}
