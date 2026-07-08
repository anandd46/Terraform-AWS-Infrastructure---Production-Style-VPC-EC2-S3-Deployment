# 📸 Screenshots Checklist

This document lists **every AWS Console screenshot** you should capture to fully document your deployment for a portfolio/GitHub README. Capture each one after successfully completing `deployment-guide.md`, then embed them in the `## Screenshots` section of `README.md` using:

```markdown
![Description](./screenshot-filename.png)
```

> 💡 **Tip:** Store screenshots directly in this same project folder (per the "no subfolders" requirement) using the exact filenames suggested below, so the README image links resolve correctly once you add them.

---

## Networking

| # | Screenshot | What to Capture | Suggested Filename |
|---|---|---|---|
| 1 | VPC Overview | VPC Console → Your VPCs, showing `production-vpc` with CIDR `10.0.0.0/16`, State = Available | `screenshot-vpc-overview.png` |
| 2 | Subnets List | VPC Console → Subnets, showing all 4 subnets with their CIDR blocks and AZs | `screenshot-subnets.png` |
| 3 | Subnet Detail (Public) | Click into `public-subnet-1`, showing "Auto-assign public IPv4" = Yes | `screenshot-public-subnet-detail.png` |
| 4 | Subnet Detail (Private) | Click into `private-subnet-1`, showing "Auto-assign public IPv4" = No | `screenshot-private-subnet-detail.png` |
| 5 | Internet Gateway | VPC Console → Internet Gateways, showing `production-vpc-igw` attached to the VPC | `screenshot-igw.png` |
| 6 | NAT Gateway | VPC Console → NAT Gateways, showing State = Available and its Elastic IP | `screenshot-nat-gateway.png` |
| 7 | Elastic IPs | VPC Console → Elastic IPs, showing both EIPs (bastion + NAT) and their associations | `screenshot-elastic-ips.png` |

## Route Tables

| # | Screenshot | What to Capture | Suggested Filename |
|---|---|---|---|
| 8 | Public Route Table | Route Tables → `public-rt` → Routes tab, showing `0.0.0.0/0 -> igw-xxxx` | `screenshot-public-route-table.png` |
| 9 | Private Route Table | Route Tables → `private-rt` → Routes tab, showing `0.0.0.0/0 -> nat-xxxx` | `screenshot-private-route-table.png` |
| 10 | Route Table Associations | Either route table → Subnet Associations tab, showing which subnets are linked | `screenshot-route-associations.png` |

## Security

| # | Screenshot | What to Capture | Suggested Filename |
|---|---|---|---|
| 11 | Security Groups List | EC2 Console → Security Groups, showing all 3 custom SGs | `screenshot-security-groups.png` |
| 12 | Bastion SG Rules | `bastion-sg` → Inbound rules tab, showing port 22 restricted to your IP | `screenshot-bastion-sg-rules.png` |
| 13 | Web SG Rules | `web-sg` → Inbound rules tab, showing ports 80/443 open and 22 referencing `bastion-sg` | `screenshot-web-sg-rules.png` |
| 14 | Private SG Rules | `private-sg` → Inbound rules tab, showing SG-to-SG references only (no public CIDRs) | `screenshot-private-sg-rules.png` |
| 15 | Network ACLs | VPC Console → Network ACLs, showing `public-nacl` and `private-nacl` with rule numbers | `screenshot-nacls.png` |

## Compute

| # | Screenshot | What to Capture | Suggested Filename |
|---|---|---|---|
| 16 | EC2 Instances List | EC2 Console → Instances, showing all 3 instances Running with their public/private IPs | `screenshot-ec2-instances.png` |
| 17 | Bastion Instance Detail | Click into the bastion instance, showing its Elastic IP and Security Group | `screenshot-bastion-detail.png` |
| 18 | Private Instance Detail | Click into the private app instance, showing "Auto-assign Public IP" = disabled | `screenshot-private-instance-detail.png` |

## Connectivity Testing

| # | Screenshot | What to Capture | Suggested Filename |
|---|---|---|---|
| 19 | EC2 Instance Connect | Terminal window showing a successful `Instance Connect` or SSH session banner to the bastion | `screenshot-instance-connect.png` |
| 20 | SSH to Bastion | Terminal showing `ssh -i key.pem ec2-user@<bastion-ip>` succeeding with the Amazon Linux MOTD | `screenshot-ssh-bastion.png` |
| 21 | SSH Hop to Private Instance | Terminal showing the ProxyJump command reaching the private instance's shell prompt | `screenshot-ssh-private-hop.png` |
| 22 | Ping Results | Terminal showing `ping` output between bastion and private instance (0% packet loss) | `screenshot-ping-results.png` |
| 23 | NAT Egress Test | Terminal on the private instance running `curl https://checkip.amazonaws.com`, showing the NAT Gateway's IP | `screenshot-nat-egress-test.png` |
| 24 | Public Web Server Response | Browser or `curl` output showing the Apache placeholder page served by the public EC2 | `screenshot-web-response.png` |

## Terraform

| # | Screenshot | What to Capture | Suggested Filename |
|---|---|---|---|
| 25 | Terraform Init | Terminal showing `terraform init` completing with "Terraform has been successfully initialized!" | `screenshot-terraform-init.png` |
| 26 | Terraform Plan | Terminal showing `terraform plan` output with the full resource-add summary | `screenshot-terraform-plan.png` |
| 27 | Terraform Apply | Terminal showing `terraform apply` completing with "Apply complete! Resources: 27 added" | `screenshot-terraform-apply.png` |
| 28 | Terraform Outputs | Terminal showing `terraform output` printing all IPs and IDs | `screenshot-terraform-outputs.png` |

## AWS CLI

| # | Screenshot | What to Capture | Suggested Filename |
|---|---|---|---|
| 29 | AWS CLI Verification | Terminal showing `aws ec2 describe-instances` output formatted with `--query` | `screenshot-aws-cli-verify.png` |
| 30 | Deployment Success Summary | A final terminal screenshot or Console dashboard view showing the complete, healthy stack | `screenshot-deployment-success.png` |

---

## Embedding Screenshots in README.md

Once captured, replace the placeholder text in the README's `## 📸 Screenshots` section with actual image embeds, for example:

```markdown
### VPC Overview
![VPC Overview](./screenshot-vpc-overview.png)

### Terraform Apply Success
![Terraform Apply](./screenshot-terraform-apply.png)
```

> **Note:** Keep all screenshot files directly inside the project's root folder alongside the other deliverables — per the project requirements, no subfolders (e.g. `images/` or `screenshots/`) should be created.
