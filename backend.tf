###############################################################################
# Terraform Remote State Backend
#
# Remote state solves the critical problem of shared infrastructure management.
# When working in teams or CI/CD pipelines, storing state locally means
# nobody else can safely apply changes — and accidental overwrites can corrupt
# the state file entirely.
#
# S3 + DynamoDB is the most widely adopted backend combination for AWS:
#   - S3 stores the state file with versioning enabled (rollback protection)
#   - DynamoDB provides state locking to prevent concurrent applies
#   - Server-side encryption (SSE) secures state at rest
#
# IMPORTANT: Before running `terraform init`, you must:
#   1. Create the S3 bucket manually (or via a bootstrap script)
#   2. Create the DynamoDB table with a partition key named "LockID"
#   3. Replace placeholder values below with your actual bucket/table names
#
# Author: Anand D
###############################################################################

terraform {
  backend "s3" {
    # The S3 bucket where the Terraform state file will be stored.
    # Replace this with your actual bucket name.
    bucket = "your-terraform-state-bucket-name"

    # The path (key) within the S3 bucket for this state file.
    # Using a path structure like this lets you store multiple project
    # state files in the same bucket without conflicts.
    key = "aws-infra/production/terraform.tfstate"

    # The AWS region where the S3 bucket and DynamoDB table reside.
    region = "us-east-1"

    # Enable server-side encryption for the state file.
    # State files often contain sensitive output values such as IPs,
    # ARNs, and sometimes secrets — encryption is non-negotiable.
    encrypt = true

    # DynamoDB table used for state locking and consistency checking.
    # Replace with your actual table name (must have "LockID" as the key).
    dynamodb_table = "terraform-state-lock"

    # Optional: specify an IAM role to assume when accessing the backend.
    # Useful in multi-account setups where the state bucket lives in a
    # central account separate from the deployment account.
    # role_arn = "arn:aws:iam::ACCOUNT_ID:role/TerraformBackendRole"
  }
}

###############################################################################
# Bootstrap Instructions
#
# Run these AWS CLI commands ONCE before your first `terraform init`:
#
# 1. Create S3 bucket:
#    aws s3api create-bucket \
#      --bucket your-terraform-state-bucket-name \
#      --region us-east-1
#
# 2. Enable versioning:
#    aws s3api put-bucket-versioning \
#      --bucket your-terraform-state-bucket-name \
#      --versioning-configuration Status=Enabled
#
# 3. Enable encryption:
#    aws s3api put-bucket-encryption \
#      --bucket your-terraform-state-bucket-name \
#      --server-side-encryption-configuration \
#        '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
#
# 4. Block public access:
#    aws s3api put-public-access-block \
#      --bucket your-terraform-state-bucket-name \
#      --public-access-block-configuration \
#        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
#
# 5. Create DynamoDB lock table:
#    aws dynamodb create-table \
#      --table-name terraform-state-lock \
#      --attribute-definitions AttributeName=LockID,AttributeType=S \
#      --key-schema AttributeName=LockID,KeyType=HASH \
#      --billing-mode PAY_PER_REQUEST \
#      --region us-east-1
###############################################################################
