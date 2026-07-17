###############################################################################
# Networking Infrastructure
#
# This file builds the entire network layer:
#   VPC → Internet Gateway → Public Subnet → Route Table → NACL
#
# Design rationale:
#   A dedicated VPC (not the default VPC) gives full control over the network
#   address space, routing, and security boundaries. The default VPC is shared,
#   publicly routable, and has no audit trail — it is unsuitable for production.
#
# Author: Anand D
###############################################################################

###############################################################################
# VPC
#
# The Virtual Private Cloud is the isolated network boundary for all resources.
# We use 10.0.0.0/16 — an RFC 1918 private range — which gives 65,534 usable
# host addresses. This headroom is intentional: as the project grows with
# private subnets, NAT gateways, and additional AZs, there is no need to
# re-address the network.
#
# enable_dns_hostnames = true  → EC2 instances get DNS names automatically,
#                                which is required for SSM and CloudWatch.
# enable_dns_support   = true  → the VPC's internal DNS resolver is active.
###############################################################################
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = local.vpc_name
  }

  lifecycle {
    # Prevent accidental destruction of the VPC while it still has resources.
    # Terraform will error out rather than silently tear down the network.
    prevent_destroy = false
  }
}

###############################################################################
# Internet Gateway
#
# The IGW attaches to the VPC and provides the path between the public subnet
# and the public internet. Without it, instances in the public subnet can talk
# to each other internally but cannot reach or be reached from outside.
###############################################################################
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = local.igw_name
  }

  # The IGW depends on the VPC being fully created before attaching.
  depends_on = [aws_vpc.main]
}

###############################################################################
# Public Subnet
#
# The public subnet (10.0.1.0/24, 254 usable addresses) lives in a single AZ.
# Resources placed here receive public IPs and are directly reachable from
# the internet via the IGW and route table.
#
# map_public_ip_on_launch = true ensures every instance launched here gets
# a public IP automatically, without needing to specify it each time.
#
# Why a /24? The project only needs a handful of instances, but a /24 is
# conventional for subnets in standard VPC designs and leaves room for more.
###############################################################################
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = var.associate_public_ip

  tags = {
    Name = local.public_subnet_name
    Tier = "public"
  }
}

###############################################################################
# Public Route Table
#
# This route table sends all non-VPC traffic (0.0.0.0/0) to the Internet
# Gateway. The association below wires the public subnet to this table,
# making instances in that subnet internet-accessible.
#
# The local route (10.0.0.0/16 → local) is added implicitly by AWS and
# handles all intra-VPC traffic without any explicit entry required.
###############################################################################
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = local.route_table_name
  }

  depends_on = [aws_internet_gateway.main]
}

# Associate the route table with the public subnet.
# Without this association, the subnet uses the VPC's main route table,
# which has no default route to the IGW.
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

###############################################################################
# Network ACL (NACL)
#
# NACLs are the stateless firewall at the subnet boundary — they apply before
# Security Groups and evaluate every packet independently (no connection tracking).
# Because they are stateless, you must explicitly allow both inbound AND outbound
# traffic for every flow, including the ephemeral port range (1024–65535) for
# return traffic on TCP connections.
#
# Rule hierarchy:
#   Rule 100  — allow HTTP (80) inbound
#   Rule 110  — allow HTTPS (443) inbound
#   Rule 120  — allow SSH (22) inbound
#   Rule 130  — allow ephemeral return ports inbound (required for stateless TCP)
#   Rule 32766 — DENY all other inbound traffic (implicit in AWS, shown explicitly)
#
# Outbound:
#   Rule 100  — allow all outbound (simplifies egress; Security Groups handle fine-grained control)
###############################################################################
resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = [aws_subnet.public.id]

  # ── Inbound Rules ──────────────────────────────────────────────────────
  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  ingress {
    rule_no    = 120
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.allowed_ssh_cidr
    from_port  = 22
    to_port    = 22
  }

  # Ephemeral ports: required for TCP response traffic.
  # When an EC2 instance makes an outbound connection (e.g., yum update),
  # the OS picks a source port in this range for the reply to arrive on.
  ingress {
    rule_no    = 130
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # ── Outbound Rules ─────────────────────────────────────────────────────
  # Allow all outbound traffic. Security Groups enforce egress rules
  # at the instance level, which is more appropriate for stateful filtering.
  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = local.nacl_name
  }
}
