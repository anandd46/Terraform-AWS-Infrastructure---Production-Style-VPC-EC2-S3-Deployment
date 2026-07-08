############################################
# provider.tf
# Provider configuration for AWS
############################################

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "Production-Style-AWS-VPC"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = var.owner
    }
  }
}
