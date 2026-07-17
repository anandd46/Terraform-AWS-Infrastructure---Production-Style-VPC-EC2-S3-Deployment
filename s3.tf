###############################################################################
# S3 Bucket Configuration
#
# This file provisions a production-grade S3 bucket with:
#   - Random suffix in the name (global uniqueness)
#   - Server-side encryption (AES-256 via SSE-S3)
#   - Object versioning (data protection / accidental delete recovery)
#   - Public access block (no accidental public exposure)
#   - Lifecycle rules (automated cost management)
#   - Bucket ownership controls (enforces object ownership to bucket owner)
#
# Why do all of this for one bucket?
#   S3 buckets have been the source of some of the largest data breaches in
#   cloud history — not because S3 is insecure, but because default settings
#   are permissive. Each configuration block below closes a specific attack
#   surface or prevents a specific operational mistake.
#
# Author: Anand D
###############################################################################

###############################################################################
# S3 Bucket
#
# The bucket name includes a random hex suffix from random_id.suffix to
# ensure global uniqueness. S3 bucket names are shared across all AWS
# accounts worldwide — a plain project name is almost certainly taken.
###############################################################################
resource "aws_s3_bucket" "main" {
  bucket        = local.s3_bucket_name
  force_destroy = var.s3_force_destroy

  tags = {
    Name    = local.s3_bucket_name
    Purpose = "project-storage"
  }

  lifecycle {
    # Prevent accidental destruction of the bucket.
    # Set force_destroy = true in terraform.tfvars only when you intend
    # to tear down the entire project and accept data loss.
    prevent_destroy = false
  }
}

###############################################################################
# Bucket Ownership Controls
#
# AWS S3 changed the default ACL behaviour in 2023 — BucketOwnerEnforced
# is now the recommended setting. This disables ACLs entirely and ensures
# all objects written to the bucket are automatically owned by the bucket
# owner account, preventing the "confused deputy" problem where another
# account uploads an object it retains ownership of.
###############################################################################
resource "aws_s3_bucket_ownership_controls" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

###############################################################################
# Public Access Block
#
# This is the most important S3 security control — it prevents any public
# access regardless of bucket policies or ACLs. All four settings are enabled:
#
#   block_public_acls        → rejects any PUT request that includes a public ACL
#   ignore_public_acls       → existing public ACLs are ignored during evaluation
#   block_public_policy      → rejects bucket policies that grant public access
#   restrict_public_buckets  → restricts access to authorized users regardless of policy
#
# Never set any of these to false unless you are serving a public static website
# and fully understand the implication.
###############################################################################
resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true

  depends_on = [aws_s3_bucket.main]
}

###############################################################################
# Server-Side Encryption
#
# AES-256 (SSE-S3) encrypts every object at rest using AWS-managed keys.
# This satisfies many compliance frameworks (PCI DSS, HIPAA, SOC 2) without
# any performance impact or cost beyond the standard S3 storage price.
#
# For environments requiring customer-managed key rotation and audit trails,
# swap SSE-S3 for SSE-KMS with a customer-managed CMK.
###############################################################################
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

###############################################################################
# Object Versioning
#
# Versioning preserves every version of every object, including overwrites
# and deletes. This is essential for:
#   - Recovering from accidental application-level deletes
#   - Rolling back to a previous configuration or artifact
#   - Meeting data retention requirements without a separate backup system
#
# The trade-off is storage cost — lifecycle rules below mitigate this by
# automatically cleaning up old versions after a defined period.
###############################################################################
resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id

  versioning_configuration {
    status = var.s3_versioning_enabled ? "Enabled" : "Suspended"
  }
}

###############################################################################
# Lifecycle Rules
#
# Without lifecycle rules, versioning causes unlimited storage growth as
# old versions accumulate forever. These rules automate cost management:
#
#   Rule 1 (noncurrent-versions):
#     - Keep the 3 most recent versions of any object
#     - Expire older versions after 90 days
#
#   Rule 2 (incomplete-multipart):
#     - Clean up multipart uploads that were started but never completed
#     - Common when large file uploads are interrupted — these fragments
#       accumulate silently and incur storage charges
###############################################################################
resource "aws_s3_bucket_lifecycle_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  # Depends on versioning being enabled — lifecycle rules on noncurrent
  # versions require versioning to be active first.
  depends_on = [aws_s3_bucket_versioning.main]

  # Rule 1: Manage non-current (old) object versions
  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days           = 90
      newer_noncurrent_versions = 3
    }

    noncurrent_version_transition {
      noncurrent_days           = 30
      storage_class             = "STANDARD_IA"
      newer_noncurrent_versions = 3
    }
  }

  # Rule 2: Abort incomplete multipart uploads after 7 days
  rule {
    id     = "abort-incomplete-multipart"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  # Rule 3: Transition current objects to cheaper storage tiers
  # Objects not accessed in 90 days move to STANDARD_IA (Infrequent Access).
  # After 365 days they move to GLACIER for archival at minimal cost.
  rule {
    id     = "transition-to-ia-and-glacier"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 365
      storage_class = "GLACIER"
    }
  }
}

###############################################################################
# Bucket Policy
#
# Enforce HTTPS-only access (deny all HTTP requests).
# Any request that arrives over an unencrypted connection is rejected,
# ensuring data in transit is always protected.
###############################################################################
resource "aws_s3_bucket_policy" "force_https" {
  bucket = aws_s3_bucket.main.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyHTTP"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.main.arn,
          "${aws_s3_bucket.main.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })

  # Public access block must be configured before the bucket policy
  # to avoid the policy being rejected as publicly accessible.
  depends_on = [aws_s3_bucket_public_access_block.main]
}
