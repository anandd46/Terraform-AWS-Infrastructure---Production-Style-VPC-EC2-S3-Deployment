

############################################################################
# terraform.tf
# Main infrastructure definition for Production-Style AWS VPC Architecture
#
# Resources created:
#   - Custom VPC
#   - 2 Public Subnets  (one per AZ)
#   - 2 Private Subnets (one per AZ)
#   - Internet Gateway
#   - NAT Gateway (or optional Free Tier NAT Instance) + Elastic IP
#   - Public & Private Route Tables + Associations
#   - Security Groups (bastion, web, private)
#   - Network ACLs (public, private)
#   - Bastion Host EC2 (public subnet)
#   - Public Web EC2 (public subnet)
#   - Private App EC2 (private subnet)
############################################################################

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # OPTIONAL remote backend - see README/deployment-guide for setup
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "production-style-aws-vpc/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "terraform-state-lock"
  #   encrypt        = true
  # }
}

# ---------------------------------------------------------------------------
# DATA SOURCES
# ---------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}

# Latest Amazon Linux 2023 AMI (used when var.ami_id is not supplied)
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  ami_id = coalesce(var.ami_id, data.aws_ami.amazon_linux.id)
  name   = var.project_name
}

# ---------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.common_tags, {
    Name = "${local.name}-vpc"
  })
}

# ---------------------------------------------------------------------------
# INTERNET GATEWAY
# ---------------------------------------------------------------------------

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name = "${local.name}-igw"
  })
}

# ---------------------------------------------------------------------------
# SUBNETS
# ---------------------------------------------------------------------------

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.common_tags, {
    Name = "${local.name}-public-subnet-${count.index + 1}"
    Tier = "Public"
  })
}

resource "aws_subnet" "private" {
  count                   = length(var.private_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = merge(var.common_tags, {
    Name = "${local.name}-private-subnet-${count.index + 1}"
    Tier = "Private"
  })
}

# ---------------------------------------------------------------------------
# ELASTIC IP + NAT GATEWAY (production path - NOT Free Tier eligible)
# ---------------------------------------------------------------------------

resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"

  tags = merge(var.common_tags, {
    Name = "${local.name}-nat-eip"
  })

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "nat" {
  count         = var.enable_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(var.common_tags, {
    Name = "${local.name}-nat-gw"
  })

  depends_on = [aws_internet_gateway.igw]
}

# ---------------------------------------------------------------------------
# FREE TIER ALTERNATIVE: NAT INSTANCE
# Only created when enable_nat_gateway = false AND enable_nat_instance = true
# ---------------------------------------------------------------------------

resource "aws_security_group" "nat_instance" {
  count       = (!var.enable_nat_gateway && var.enable_nat_instance) ? 1 : 0
  name        = "${local.name}-nat-instance-sg"
  description = "Allows inbound traffic from private subnets and outbound to internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "All traffic from within the VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, { Name = "${local.name}-nat-instance-sg" })
}

resource "aws_instance" "nat_instance" {
  count                       = (!var.enable_nat_gateway && var.enable_nat_instance) ? 1 : 0
  ami                         = local.ami_id
  instance_type               = var.nat_instance_type
  subnet_id                   = aws_subnet.public[0].id
  key_name                    = var.key_pair_name
  vpc_security_group_ids      = [aws_security_group.nat_instance[0].id]
  source_dest_check           = false # REQUIRED for NAT instances
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              # Enable IP forwarding and configure NAT via iptables masquerade
              sysctl -w net.ipv4.ip_forward=1
              echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
              /sbin/iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
              /sbin/iptables-save > /etc/sysconfig/iptables
              EOF

  tags = merge(var.common_tags, { Name = "${local.name}-nat-instance" })
}

resource "aws_eip" "nat_instance" {
  count    = (!var.enable_nat_gateway && var.enable_nat_instance) ? 1 : 0
  domain   = "vpc"
  instance = aws_instance.nat_instance[0].id

  tags = merge(var.common_tags, { Name = "${local.name}-nat-instance-eip" })
}

# ---------------------------------------------------------------------------
# ROUTE TABLES
# ---------------------------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(var.common_tags, {
    Name = "${local.name}-public-rt"
  })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.nat[0].id
    }
  }

  dynamic "route" {
    for_each = (!var.enable_nat_gateway && var.enable_nat_instance) ? [1] : []
    content {
      cidr_block  = "0.0.0.0/0"
      instance_id = aws_instance.nat_instance[0].id
    }
  }

  tags = merge(var.common_tags, {
    Name = "${local.name}-private-rt"
  })
}

# ---------------------------------------------------------------------------
# ROUTE TABLE ASSOCIATIONS
# ---------------------------------------------------------------------------

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ---------------------------------------------------------------------------
# NETWORK ACLs
# ---------------------------------------------------------------------------

resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.public[*].id

  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    rule_no    = 120
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  ingress {
    rule_no    = 130
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(var.common_tags, { Name = "${local.name}-public-nacl" })
}

resource "aws_network_acl" "private" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private[*].id

  ingress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(var.common_tags, { Name = "${local.name}-private-nacl" })
}

# ---------------------------------------------------------------------------
# SECURITY GROUPS
# ---------------------------------------------------------------------------

resource "aws_security_group" "bastion" {
  name        = "${local.name}-bastion-sg"
  description = "Allows SSH from the administrator's IP only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from admin IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_ip_cidr]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, { Name = "${local.name}-bastion-sg" })
}

resource "aws_security_group" "web" {
  name        = "${local.name}-web-sg"
  description = "Allows HTTP/HTTPS from the internet and SSH from the bastion"
  vpc_id      = aws_vpc.main.id

  dynamic "ingress" {
    for_each = var.allowed_web_ports
    content {
      description = "Web traffic on port ${ingress.value}"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  ingress {
    description     = "SSH from bastion host only"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, { Name = "${local.name}-web-sg" })
}

resource "aws_security_group" "private" {
  name        = "${local.name}-private-sg"
  description = "Allows SSH from bastion and app traffic from the web tier only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "SSH from bastion host only"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  ingress {
    description     = "App/DB traffic from web tier only"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    description = "All outbound traffic (routed via NAT)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, { Name = "${local.name}-private-sg" })
}

# ---------------------------------------------------------------------------
# EC2 INSTANCES
# ---------------------------------------------------------------------------

# Bastion Host - Public Subnet A
resource "aws_instance" "bastion" {
  ami                         = local.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[0].id
  key_name                    = var.key_pair_name
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = true

  tags = merge(var.common_tags, { Name = "${local.name}-bastion-host" })
}

# Public Web Server - Public Subnet A
resource "aws_instance" "public_web" {
  ami                         = local.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[0].id
  key_name                    = var.key_pair_name
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              dnf -y install httpd || yum -y install httpd
              systemctl enable httpd
              systemctl start httpd
              echo "<h1>Production-Style AWS VPC - Public Web Server</h1>" > /var/www/html/index.html
              EOF

  tags = merge(var.common_tags, { Name = "${local.name}-public-web" })
}

# Private Application Server - Private Subnet A
resource "aws_instance" "private_app" {
  ami                     = local.ami_id
  instance_type           = var.instance_type
  subnet_id               = aws_subnet.private[0].id
  key_name                = var.key_pair_name
  vpc_security_group_ids  = [aws_security_group.private.id]

  tags = merge(var.common_tags, { Name = "${local.name}-private-app" })
}

# Elastic IP for the Bastion Host (static address for SSH access)
resource "aws_eip" "bastion" {
  domain   = "vpc"
  instance = aws_instance.bastion.id

  tags = merge(var.common_tags, { Name = "${local.name}-bastion-eip" })

  depends_on = [aws_internet_gateway.igw]
}
