###############################################################################
# IAM Configuration
#
# Identity and Access Management is the security backbone of any AWS deployment.
# This file provisions:
#
#   1. IAM Role + Trust Policy   — allows EC2 to assume the role
#   2. IAM Policy                — least-privilege permissions for the role
#   3. IAM Instance Profile      — the wrapper that attaches a role to EC2
#   4. Role Policy Attachment    — binds the custom policy to the role
#   5. IAM User                  — a demo IAM user (not used for EC2)
#
# Why use an IAM Role instead of access keys on the instance?
#   Access keys embedded in user data or environment variables are a serious
#   security risk — they can be extracted from memory, logs, or metadata.
#   IAM Roles are automatically rotated by AWS, scoped to the instance, and
#   require zero secret management on the operator's part.
#
# Author: Anand D
###############################################################################

###############################################################################
# IAM Role — EC2 Assume Role
#
# This role is assumed by the EC2 service on behalf of the instance.
# The trust policy (assume role policy) explicitly allows only the EC2
# service principal to request temporary credentials through STS.
###############################################################################
resource "aws_iam_role" "ec2_role" {
  name        = local.iam_role_name
  description = "Role assumed by EC2 instances in ${local.name_prefix} — grants least-privilege access to CloudWatch, S3, and SSM."
  path        = "/"

  # Trust policy: who can assume this role.
  # Only the EC2 service can request credentials — no IAM users or other
  # services can assume this role unless added explicitly.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEC2ToAssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = local.iam_role_name
  }

  lifecycle {
    create_before_destroy = true
  }
}

###############################################################################
# IAM Policy — Least Privilege Permissions
#
# The custom policy grants exactly what this workload needs:
#   - CloudWatch Logs: write application logs from the CloudWatch agent
#   - CloudWatch Metrics: publish custom instance metrics
#   - S3: read/write access scoped to the project bucket only (not all buckets)
#   - SSM: Session Manager access for secure shell without open port 22
#   - EC2 Describe: allows the instance to discover its own metadata
#
# Permissions are scoped to specific resources where possible.
# No asterisk (*) resource ARNs are used on write operations.
###############################################################################
resource "aws_iam_policy" "ec2_policy" {
  name        = local.iam_policy_name
  description = "Least-privilege permissions for EC2 instances in ${local.name_prefix}"
  path        = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [

      # ── CloudWatch Logs ────────────────────────────────────────────────
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups"
        ]
        Resource = [
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:${local.cw_log_group_name}",
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:${local.cw_log_group_name}:*"
        ]
      },

      # ── CloudWatch Metrics ─────────────────────────────────────────────
      {
        Sid    = "AllowCloudWatchMetrics"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      },

      # ── S3 Access (scoped to project bucket only) ──────────────────────
      {
        Sid    = "AllowS3BucketAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.main.arn,
          "${aws_s3_bucket.main.arn}/*"
        ]
      },

      # ── SSM Session Manager ────────────────────────────────────────────
      # These permissions allow the AWS SSM agent to register the instance
      # and enable Session Manager sessions — a secure alternative to SSH.
      {
        Sid    = "AllowSSMCoreAccess"
        Effect = "Allow"
        Action = [
          "ssm:DescribeAssociation",
          "ssm:GetDeployablePatchSnapshotForInstance",
          "ssm:GetDocument",
          "ssm:DescribeDocument",
          "ssm:GetManifest",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:ListAssociations",
          "ssm:ListInstanceAssociations",
          "ssm:PutInventory",
          "ssm:PutComplianceItems",
          "ssm:PutConfigurePackageResult",
          "ssm:UpdateAssociationStatus",
          "ssm:UpdateInstanceAssociationStatus",
          "ssm:UpdateInstanceInformation"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowSSMMessages"
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowEC2Messages"
        Effect = "Allow"
        Action = [
          "ec2messages:AcknowledgeMessage",
          "ec2messages:DeleteMessage",
          "ec2messages:FailMessage",
          "ec2messages:GetEndpoint",
          "ec2messages:GetMessages",
          "ec2messages:SendReply"
        ]
        Resource = "*"
      },

      # ── EC2 Self-Discovery ─────────────────────────────────────────────
      # Read-only: allows scripts on the instance to query its own metadata.
      {
        Sid    = "AllowEC2Describe"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "ec2:DescribeVolumes"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = local.iam_policy_name
  }
}

###############################################################################
# Policy Attachment — Bind Custom Policy to Role
###############################################################################
resource "aws_iam_role_policy_attachment" "ec2_custom_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_policy.arn
}

# Additionally, attach the AWS-managed SSM policy for full Session Manager support.
# This managed policy is maintained by AWS and kept up-to-date with SSM requirements.
resource "aws_iam_role_policy_attachment" "ec2_ssm_managed" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

###############################################################################
# IAM Instance Profile
#
# EC2 does not accept IAM roles directly — it needs a wrapper called an
# Instance Profile. The profile is what you specify when launching an instance,
# and AWS internally resolves it to the attached role to issue temporary
# credentials via the EC2 metadata service (IMDSv2).
###############################################################################
resource "aws_iam_instance_profile" "ec2_profile" {
  name = local.instance_profile_name
  role = aws_iam_role.ec2_role.name

  tags = {
    Name = local.instance_profile_name
  }

  depends_on = [aws_iam_role.ec2_role]
}

###############################################################################
# IAM User — Demo User
#
# This user is created for demonstration purposes to show how Terraform
# manages IAM users. In a real environment, human access to AWS should be
# managed through IAM Identity Center (SSO), not long-lived IAM users.
###############################################################################
resource "aws_iam_user" "demo_user" {
  name          = var.iam_user_name
  path          = "/"
  force_destroy = true

  tags = {
    Name    = var.iam_user_name
    Purpose = "terraform-demo"
  }
}

# Create a login profile (console access) for the demo user.
# password_reset_required = true forces the user to set a new password
# at first login — this is a security requirement.
resource "aws_iam_user_login_profile" "demo_user" {
  user                    = aws_iam_user.demo_user.name
  password_reset_required = true
  password_length         = 16

  lifecycle {
    # Ignore subsequent password changes made by the user through the console.
    ignore_changes = [password_length, password_reset_required]
  }
}
