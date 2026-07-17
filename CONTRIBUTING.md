# Contributing to aws-infra-terraform

Thank you for considering a contribution. Whether you are fixing a typo, improving a comment, or proposing a new AWS resource — every improvement makes the project better for everyone learning cloud infrastructure.

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How to Contribute](#how-to-contribute)
- [Development Setup](#development-setup)
- [Branch Naming Convention](#branch-naming-convention)
- [Commit Message Format](#commit-message-format)
- [Pull Request Process](#pull-request-process)
- [Terraform Coding Standards](#terraform-coding-standards)
- [Testing](#testing)
- [Reporting Bugs](#reporting-bugs)
- [Suggesting Enhancements](#suggesting-enhancements)

---

## Code of Conduct

This project follows a simple rule: be respectful and constructive. Criticism of code and ideas is welcome; personal attacks are not. If you see behaviour that violates this, open an issue.

---

## How to Contribute

1. **Fork** the repository on GitHub.
2. **Clone** your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/aws-infra-terraform.git
   cd aws-infra-terraform
   ```
3. Create a **feature branch** (see naming convention below).
4. Make your changes.
5. **Test** locally with `terraform validate` and `terraform plan`.
6. Push the branch and open a **Pull Request** against `main`.

---

## Development Setup

### Prerequisites

| Tool           | Minimum Version | Install                                   |
|----------------|-----------------|-------------------------------------------|
| Terraform      | 1.5.0           | https://developer.hashicorp.com/terraform/install |
| AWS CLI        | 2.x             | https://aws.amazon.com/cli/               |
| Git            | 2.x             | https://git-scm.com/                      |
| tflint         | 0.50+           | https://github.com/terraform-linters/tflint |
| terraform-docs | 0.16+           | https://terraform-docs.io/               |

### Local Workflow

```bash
# 1. Format code (always before committing)
terraform fmt -recursive

# 2. Validate configuration
terraform validate

# 3. Lint with tflint
tflint --init
tflint

# 4. Plan against a real AWS account (use a non-production account)
export AWS_PROFILE=dev
terraform plan -out=tfplan

# 5. Review the plan carefully before applying
terraform show tfplan
```

---

## Branch Naming Convention

Use descriptive, hyphenated branch names with a category prefix:

| Category    | Pattern                    | Example                          |
|-------------|----------------------------|----------------------------------|
| Feature     | `feature/short-description`| `feature/add-nat-gateway`        |
| Bug fix     | `fix/short-description`    | `fix/nacl-ephemeral-ports`       |
| Docs        | `docs/short-description`   | `docs/update-deployment-guide`   |
| Refactor    | `refactor/short-description`| `refactor/split-iam-policies`   |
| Security    | `security/short-description`| `security/enforce-imdsv2`       |

---

## Commit Message Format

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <short description>

[optional body — explain WHY, not just what]

[optional footer — references to issues]
```

**Types:**

| Type       | When to use                                            |
|------------|--------------------------------------------------------|
| `feat`     | A new resource or feature                              |
| `fix`      | Corrects a broken configuration                        |
| `docs`     | Documentation-only changes                             |
| `refactor` | Code restructuring with no functional change           |
| `security` | Security hardening (IAM tightening, encryption, etc.)  |
| `perf`     | Performance improvements                               |
| `chore`    | Dependency bumps, version constraints                  |

**Examples:**

```
feat(network): add private subnet and NAT gateway

Adds a private subnet in us-east-1b for backend resources that should not
have direct internet access. A NAT gateway in the public subnet provides
outbound-only internet access for package updates.

Closes #14

---

fix(iam): scope S3 write permissions to bucket ARN only

The original policy used Resource = "*" for s3:PutObject which violated
least-privilege. Changed to restrict to the specific project bucket ARN.

---

docs(readme): add architecture diagram for multi-AZ design
```

---

## Pull Request Process

1. Ensure `terraform fmt -check` passes (no formatting differences).
2. Ensure `terraform validate` returns no errors.
3. Run `tflint` and address any warnings — do not suppress linter rules without a comment explaining why.
4. Update `CHANGELOG.md` under `[Unreleased]` with a summary of your change.
5. If you are adding a new variable, update the Variables table in `README.md`.
6. If you are adding a new output, update the Outputs table in `README.md`.
7. Fill in the PR template completely — empty descriptions will not be reviewed.
8. Request a review from the maintainer.

PRs that touch security-sensitive areas (IAM policies, security groups, encryption settings) will be reviewed with extra scrutiny. This is intentional — a poorly scoped IAM policy in a learning project still teaches bad habits.

---

## Terraform Coding Standards

These standards keep the codebase consistent and reviewable:

### Naming
- Resource names: `snake_case` (e.g., `aws_instance.main`, `aws_subnet.public`)
- Variable names: `snake_case` (e.g., `vpc_cidr`, `instance_type`)
- Local names: `snake_case` (e.g., `name_prefix`, `s3_bucket_name`)
- No abbreviations unless universally understood (`vpc`, `iam`, `ec2`, `s3`)

### File Organisation
- One logical concern per file: `network.tf`, `iam.tf`, `ec2.tf`, `s3.tf`
- `variables.tf` — all input variables with descriptions and validation
- `outputs.tf` — all outputs with descriptions
- `locals.tf` — all computed/derived values
- `main.tf` — data sources and random resources only

### Comments
- Every resource block must have a comment explaining WHY it exists, not just what it does
- Comment non-obvious attribute values (e.g., why `http_tokens = "required"`, why `gp3` over `gp2`)
- Use `###` section separators to visually group related blocks within a file

### Variables
- Every variable must have a `description`
- Every variable must have a `default` where sensible
- Add a `validation` block for any variable where an incorrect value would cause a confusing error downstream

### Lifecycle
- Use `create_before_destroy = true` for resources that other resources depend on (Security Groups, IAM roles)
- Use `ignore_changes` sparingly and always include a comment explaining what would trigger the change and why we ignore it

### Security Non-Negotiables
- No hardcoded credentials, account IDs, or secrets in any `.tf` file
- S3 buckets must always have `aws_s3_bucket_public_access_block` with all four settings `true`
- EC2 instances must enforce IMDSv2 (`http_tokens = "required"`)
- EBS volumes must have `encrypted = true`
- IAM policies must use specific resource ARNs for write operations — no `Resource = "*"` on mutating actions

---

## Testing

### Manual Validation

At minimum, run the following before submitting a PR:

```bash
# Format check
terraform fmt -check -recursive

# Validation
terraform validate

# Lint
tflint --recursive

# Plan (against a real dev account, never production)
terraform plan
```

### What to Check in the Plan

- No unexpected resource **destroys** (especially VPCs, IAM roles, S3 buckets)
- Resource names follow the `${project_name}-${environment}` prefix convention
- No sensitive values appear in plain text in the plan output
- `depends_on` relationships are correct and nothing is created out of order

### Automated Testing (Future)

The project roadmap includes Terratest integration. If you are adding a new resource, consider writing a companion test that:
1. Applies the configuration
2. Verifies the resource exists and has the expected attributes
3. Destroys the resource

---

## Reporting Bugs

Open a GitHub Issue and include:

- **Terraform version**: `terraform version`
- **AWS Provider version**: from `.terraform.lock.hcl`
- **AWS Region**: where you are deploying
- **Steps to reproduce**: exact commands run
- **Expected behaviour**: what you thought would happen
- **Actual behaviour**: what actually happened (include the full error message)
- **Plan output** (if relevant, redact account IDs)

---

## Suggesting Enhancements

Open a GitHub Issue with the label `enhancement` and describe:

- What problem it solves or what capability it adds
- Which AWS services or Terraform resources would be involved
- Whether it would require a breaking change to existing variables or outputs
- Your rough implementation idea (pseudocode or prose is fine)

Feature requests that align with the project's goal — demonstrating production-grade IaC patterns for learning purposes — are most likely to be accepted.

---

*Thank you for helping make this project better.*
