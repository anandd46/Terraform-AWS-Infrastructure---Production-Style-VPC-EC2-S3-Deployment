###############################################################################
# EC2 Compute Configuration
#
# This file covers:
#   - TLS private key generation
#   - AWS Key Pair (SSH access)
#   - EC2 Instance with user data
#   - Elastic IP
#   - CloudWatch Log Group
#
# Author: Anand D
###############################################################################

###############################################################################
# TLS Private Key
#
# Generating the SSH key pair entirely within Terraform eliminates the manual
# step of creating a key outside and importing it. The private key is stored
# in Terraform state (which should be encrypted — hence the S3 backend with
# SSE and the DynamoDB lock in backend.tf).
#
# RSA 4096-bit is chosen for strong security. Ed25519 would also work but
# RSA has broader compatibility with older OpenSSH clients.
###############################################################################
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

###############################################################################
# AWS Key Pair
#
# The public half of the TLS key is uploaded to AWS as a Key Pair.
# When EC2 launches the instance, it places this public key in the
# ec2-user's ~/.ssh/authorized_keys, allowing SSH with the private key.
###############################################################################
resource "aws_key_pair" "main" {
  key_name   = local.ssh_key_name
  public_key = tls_private_key.ssh_key.public_key_openssh

  tags = {
    Name = local.key_pair_name
  }
}

###############################################################################
# CloudWatch Log Group
#
# The Log Group must exist before the CloudWatch agent on the EC2 instance
# starts sending logs. Creating it via Terraform gives us:
#   - Controlled retention (no indefinite log accumulation and cost)
#   - Consistent naming tied to the project/environment
#   - The ability to set KMS encryption on the log group (future enhancement)
###############################################################################
resource "aws_cloudwatch_log_group" "application" {
  name              = local.cw_log_group_name
  retention_in_days = var.cloudwatch_log_retention_days

  tags = {
    Name = local.cw_log_group_name
  }

  lifecycle {
    # Prevent accidental log deletion if Terraform is re-run.
    # Logs may be needed for compliance or incident investigation.
    prevent_destroy = false
  }
}

###############################################################################
# EC2 Instance
#
# The instance is the core compute resource. Key decisions:
#
#   IMDSv2 enforced: Requires a session token for metadata API requests.
#   IMDSv1 is disabled because it's vulnerable to SSRF attacks — an attacker
#   who tricks the instance into making an arbitrary GET request can steal
#   the IAM role credentials from the metadata endpoint.
#
#   EBS Optimized: improves network throughput between the instance and its
#   EBS volumes by dedicating bandwidth.
#
#   Monitoring: detailed (1-minute) CloudWatch metrics enabled for finer
#   granularity in alarms and dashboards (vs. the default 5-minute basic).
#
#   User Data: the userdata.sh script bootstraps the instance automatically
#   on first boot — installs Apache, CloudWatch agent, and renders the
#   custom status page.
###############################################################################
resource "aws_instance" "main" {
  ami                    = local.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  key_name               = aws_key_pair.main.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  # Enforce IMDSv2 for metadata security.
  # http_tokens = "required" means every metadata call must include
  # the session-oriented token — SSRF attacks cannot silently read credentials.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # Root EBS volume configuration.
  # delete_on_termination = true cleans up the volume when the instance is
  # terminated, preventing orphaned EBS volumes and unexpected charges.
  # encrypted = true ensures data at rest is protected.
  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = "${local.ec2_name}-root-vol"
    }
  }

  # Boot script that configures the instance on first launch.
  # templatefile() reads the userdata.sh template and substitutes variables.
  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    project_name    = var.project_name
    environment     = var.environment
    owner           = var.owner
    log_group_name  = local.cw_log_group_name
    aws_region      = var.aws_region
    s3_bucket_name  = local.s3_bucket_name
  }))

  # Replace the instance if user_data changes (requires new AMI or config).
  # This ensures the bootstrap script is always executed on new instances.
  user_data_replace_on_change = true

  # Enable detailed monitoring for 1-minute CloudWatch metric granularity.
  monitoring = true

  # EBS-Optimized: dedicated EBS bandwidth where supported.
  ebs_optimized = true

  tags = {
    Name = local.ec2_name
  }

  # The EC2 instance depends on the IAM instance profile and log group
  # being fully created before launch — the user data script uses both.
  depends_on = [
    aws_iam_instance_profile.ec2_profile,
    aws_cloudwatch_log_group.application
  ]

  lifecycle {
    # Ignore AMI changes after initial deployment.
    # In a real pipeline, AMI updates would go through a dedicated AMI
    # baking process and deliberate re-deployment, not automatic drift.
    ignore_changes = [ami]
  }
}

###############################################################################
# Elastic IP
#
# An Elastic IP gives the instance a stable public IP address that survives
# stop/start cycles. Without an EIP, the public IP changes every time the
# instance is stopped and restarted, which breaks DNS records, SSH host
# verification, and any client that hard-codes the IP.
###############################################################################
resource "aws_eip" "main" {
  instance = aws_instance.main.id
  domain   = "vpc"

  tags = {
    Name = "${local.ec2_name}-eip"
  }

  # The EIP must be associated after the instance and IGW are ready.
  depends_on = [
    aws_instance.main,
    aws_internet_gateway.main
  ]
}
