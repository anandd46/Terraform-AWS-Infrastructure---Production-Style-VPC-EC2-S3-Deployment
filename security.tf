###############################################################################
# Security Groups
#
# Security Groups are stateful virtual firewalls that control inbound and
# outbound traffic at the instance level. Unlike NACLs, they track connection
# state — so an allowed inbound rule automatically permits the response
# traffic without an explicit outbound rule for the return port.
#
# Design principles applied here:
#   1. Least privilege — open only the minimum set of ports required.
#   2. Named descriptions on every rule — essential for operational clarity.
#   3. Separate ingress and egress blocks — explicit is safer than implicit.
#   4. Egress: allow all outbound (common for EC2 needing package updates,
#      CloudWatch metrics, and SSM communication).
#
# Author: Anand D
###############################################################################

###############################################################################
# EC2 Security Group
#
# Allows:
#   - SSH (22)   from the configured CIDR (var.allowed_ssh_cidr)
#   - HTTP (80)  from anywhere — for the demo Apache webpage
#   - HTTPS (443) from anywhere — for TLS traffic
#   - All outbound traffic (egress)
#
# In a mature setup, SSH access would be removed entirely and replaced by
# AWS Systems Manager Session Manager, eliminating the need for an open
# port 22 and a bastion host.
###############################################################################
resource "aws_security_group" "ec2" {
  name        = local.sg_name
  description = "Security group for the ${local.name_prefix} EC2 instance"
  vpc_id      = aws_vpc.main.id

  # ── Inbound: SSH ─────────────────────────────────────────────────────────
  ingress {
    description = "SSH access from allowed CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # ── Inbound: HTTP ────────────────────────────────────────────────────────
  ingress {
    description = "HTTP access for the Apache demo webpage"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.allowed_http_cidr]
  }

  # ── Inbound: HTTPS ───────────────────────────────────────────────────────
  ingress {
    description = "HTTPS access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ── Inbound: ICMP (ping) ─────────────────────────────────────────────────
  # Allowing ICMP makes it easy to verify connectivity with a simple ping.
  # Disable this in hardened production environments.
  ingress {
    description = "ICMP ping for connectivity testing"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ── Outbound: All Traffic ─────────────────────────────────────────────────
  # Full egress is allowed so the instance can:
  #   - Update packages via yum/dnf
  #   - Send logs to CloudWatch
  #   - Communicate with AWS APIs (S3, SSM, IAM)
  #   - Pull from external repositories
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = local.sg_name
  }

  lifecycle {
    # Create a replacement Security Group before destroying the old one.
    # This prevents downtime if SG rules are updated while the instance is running.
    create_before_destroy = true
  }
}
