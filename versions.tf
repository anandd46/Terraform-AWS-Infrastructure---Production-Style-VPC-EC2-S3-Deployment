###############################################################################
# Terraform Version Constraints
#
# Pinning versions ensures reproducible builds across all environments.
# Using ~> (pessimistic constraint) allows patch upgrades but prevents
# breaking changes from minor or major version bumps.
#
# Author: Anand D
###############################################################################

terraform {
  # Minimum Terraform CLI version required to execute this configuration.
  # Terraform 1.5+ introduced check blocks and import blocks — features
  # that reflect how modern IaC should be written.
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    # AWS Provider — the core provider for all AWS resource management.
    # Version 5.x introduced significant improvements to resource management
    # and aligns with the latest AWS APIs.
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    # Random Provider — used to generate unique suffixes for resource names,
    # ensuring no naming collisions across deployments or accounts.
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }

    # TLS Provider — used to generate an RSA private key for the EC2 SSH
    # key pair entirely within Terraform, avoiding manual key management.
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
