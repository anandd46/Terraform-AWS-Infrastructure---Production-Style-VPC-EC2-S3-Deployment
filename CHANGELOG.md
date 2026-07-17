# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned
- Private subnet + NAT Gateway for backend workloads
- AWS Certificate Manager (ACM) integration for HTTPS
- Application Load Balancer in front of EC2
- Auto Scaling Group for high availability
- RDS (PostgreSQL) instance in private subnet
- ElastiCache (Redis) for session management
- AWS WAF rules on the load balancer
- GitHub Actions CI/CD pipeline for automated Terraform deployments
- Terratest integration tests
- Multi-AZ network design

---

## [1.3.0] — 2024-12-01

### Added
- IMDSv2 enforcement on EC2 instance (`http_tokens = "required"`)
- EBS volume encryption (`encrypted = true`) on root block device
- S3 bucket policy enforcing HTTPS-only access (`aws:SecureTransport`)
- `bucket_key_enabled = true` on S3 SSE configuration for cost optimisation
- `ebs_optimized = true` flag on EC2 instance
- `user_data_replace_on_change = true` to force instance refresh on bootstrap changes
- Additional CloudWatch metrics: disk I/O, network bytes, inode usage
- Random password generation for IAM demo user

### Changed
- Upgraded AWS Provider constraint from `~> 4.0` to `~> 5.0`
- Switched root volume type from `gp2` to `gp3` (lower cost, better baseline performance)
- Expanded NACL rule set to include ICMP and ephemeral port range explicitly
- Increased IAM policy specificity — S3 write actions now scoped to bucket ARN only

### Fixed
- Race condition in IAM instance profile creation — added `depends_on` to EC2 instance

---

## [1.2.0] — 2024-10-15

### Added
- CloudWatch Agent full configuration (logs + metrics)
- Custom metric namespace `CustomMetrics/${project_name}`
- S3 lifecycle rules: IA transition at 30 days, Glacier at 365 days
- S3 lifecycle rule to abort incomplete multipart uploads after 7 days
- `aws_s3_bucket_ownership_controls` with `BucketOwnerEnforced`
- Validation rules on all `variables.tf` inputs
- `additional_tags` variable for flexible tag merging
- `deployment_summary` composite output block

### Changed
- Separated monolithic `main.tf` into purpose-specific files: `network.tf`, `security.tf`, `iam.tf`, `ec2.tf`, `s3.tf`
- Moved IAM assume role policy to `jsonencode()` inline (no external JSON files)
- Enhanced userdata.sh to use IMDSv2 token for all metadata calls

### Removed
- Hard-coded AMI ID — replaced with `data.aws_ami` data source for latest Amazon Linux 2023

---

## [1.1.0] — 2024-08-20

### Added
- Network ACL (`aws_network_acl`) with stateless inbound/outbound rules
- Elastic IP (`aws_eip`) for stable public addressing
- TLS private key generation via `tls_private_key` resource
- Remote state backend configuration (S3 + DynamoDB)
- `random_id.suffix` for globally unique S3 bucket names
- `templatefile()` usage in user data for variable substitution
- `aws_iam_user_login_profile` with `password_reset_required`

### Changed
- Moved common tags to `locals.tf` and wired into provider `default_tags`
- SSM managed policy (`AmazonSSMManagedInstanceCore`) attached to EC2 role
- CloudWatch log retention set to variable `cloudwatch_log_retention_days`

---

## [1.0.0] — 2024-06-10

### Added
- Initial project structure
- AWS Provider and version constraints
- VPC with DNS support enabled
- Internet Gateway and public route table
- Public subnet with automatic public IP assignment
- Security Group (SSH, HTTP, HTTPS, ICMP)
- EC2 instance (Amazon Linux 2, t3.micro)
- S3 bucket with versioning and public access block
- IAM Role + custom policy + instance profile
- CloudWatch Log Group
- Apache HTTPD via user data
- `variables.tf` with defaults
- `outputs.tf` with key resource attributes
- `terraform.tfvars` with environment values
- `.gitignore` for Terraform and secrets
- `README.md`, `LICENSE`, `CONTRIBUTING.md`

---

[Unreleased]: https://github.com/anandd/aws-infra-terraform/compare/v1.3.0...HEAD
[1.3.0]: https://github.com/anandd/aws-infra-terraform/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/anandd/aws-infra-terraform/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/anandd/aws-infra-terraform/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/anandd/aws-infra-terraform/releases/tag/v1.0.0
