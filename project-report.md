# 📄 Project Report — Production-Style AWS VPC Architecture

## 1. Introduction

Cloud networking is the foundation on which every secure, scalable AWS workload is built. This project implements a **production-style Amazon Virtual Private Cloud (VPC)** that demonstrates the core networking patterns used in real enterprise environments: multi-AZ high availability, public/private subnet segmentation, controlled internet egress via NAT, layered security using both Security Groups and Network ACLs, and secure administrative access through a Bastion Host. The goal of this report is to document the design decisions, implementation process, testing methodology, and lessons learned while building this project, in a format suitable for a technical portfolio or interview discussion.

## 2. Objectives

- Design and implement a custom VPC with realistic, non-default CIDR planning.
- Demonstrate high availability by spreading subnets across two Availability Zones.
- Separate public-facing and internal resources using public and private subnets.
- Implement controlled, one-way internet access for private resources via a NAT Gateway (with a documented Free Tier alternative).
- Apply defense-in-depth security using both stateful Security Groups and stateless Network ACLs.
- Provide secure SSH access to private resources exclusively through a Bastion Host.
- Automate the entire deployment using Terraform, while also documenting equivalent manual AWS Console and AWS CLI procedures.
- Produce professional, portfolio-ready documentation covering architecture, deployment, cost, and interview preparation.

## 3. Architecture

The architecture consists of:

- **1 custom VPC** (`10.0.0.0/16`)
- **2 Availability Zones**, each containing one public and one private subnet
- **1 Internet Gateway**, attached to the VPC and referenced by the public route table
- **1 NAT Gateway**, deployed in Public Subnet A with an associated Elastic IP, referenced by the private route table
- **2 route tables** (public and private) with explicit subnet associations
- **2 Network ACLs** (public and private) providing subnet-level, stateless filtering
- **3 Security Groups** (`bastion-sg`, `web-sg`, `private-sg`) providing instance-level, stateful filtering, with SG-to-SG references used instead of open CIDR ranges wherever possible
- **3 EC2 instances**: a Bastion Host and a public web server in the public subnet, and an application server in the private subnet
- **1 Elastic IP**, attached to the Bastion Host for a stable SSH endpoint

Full diagrams are provided as PNG files (`architecture.png`, `vpc-topology.png`, `routing-diagram.png`, `network-flow.png`, `security-group-diagram.png`) and referenced throughout `README.md`.

## 4. Implementation

The implementation was carried out using **Terraform** as the primary Infrastructure-as-Code tool, split across `provider.tf` (AWS provider + default tags), `terraform.tf` (all resource definitions), `variables.tf` (all configurable inputs), and `outputs.tf` (deployment outputs such as IPs and resource IDs). A `terraform.tfvars.example` file documents every variable a user needs to customize (region, CIDR ranges, admin IP, NAT strategy) without committing sensitive values to version control.

Key implementation decisions:

- **`for_each`/`count` and dynamic blocks** were used throughout (subnets, NACL rules, SG ingress rules, conditional NAT resources) to keep the configuration DRY and to make the NAT Gateway vs. NAT Instance choice a single boolean flag (`enable_nat_gateway`).
- **Data sources** (`aws_ami`, `aws_availability_zones`) were used instead of hardcoded AMI IDs, so the configuration remains valid as AMIs are deprecated and replaced over time.
- **`source_dest_check = false`** was explicitly set on the optional NAT Instance, since this is a well-known gotcha that causes NAT instances to silently fail to forward traffic if omitted.
- **Default tags** at the provider level ensure every resource is consistently tagged with `Project`, `Environment`, `ManagedBy`, and `Owner`, which is a real-world best practice for cost allocation and resource tracking.

An equivalent manual path was also documented in `aws-cli-commands.md` (AWS CLI) and `deployment-guide.md` (AWS Console), so the same architecture can be reproduced or understood without Terraform — useful both as a learning exercise and as a disaster-recovery reference.

## 5. Testing

The following tests were used to validate the deployment:

1. **Terraform plan/apply validation** — confirmed the expected ~27 resources were created with no errors.
2. **SSH connectivity test** — confirmed the Bastion Host is reachable via SSH only from the configured admin IP, and confirmed the private instance is reachable only via an SSH hop through the bastion (`ssh -J`).
3. **NAT egress test** — from the private instance, `curl https://checkip.amazonaws.com` was used to confirm outbound traffic correctly exits through the NAT Gateway's Elastic IP rather than being blocked or routed incorrectly.
4. **Inbound isolation test** — confirmed the private instance has no public IP and is not reachable directly from the internet.
5. **Web server test** — confirmed the public EC2 instance serves HTTP traffic on port 80 to any source, as expected for a public-facing web tier.
6. **Security group boundary test** — attempted (and confirmed failure of) direct SSH from a non-whitelisted IP to the bastion, and direct SSH from the internet to the private instance, validating that security controls behave as designed.
7. **Route table verification** — confirmed via `aws ec2 describe-route-tables` that the public route table points `0.0.0.0/0` to the IGW and the private route table points `0.0.0.0/0` to the NAT Gateway.

## 6. Results

All objectives were met. The deployed architecture correctly demonstrates production-style network segmentation: public resources are internet-facing and independently reachable, private resources are fully isolated from inbound internet traffic while retaining outbound connectivity through NAT, and all administrative access is funneled through a single hardened Bastion Host. The Free Tier alternative (NAT Instance) was also implemented and validated as a toggle (`enable_nat_gateway = false`), allowing the same architecture to be deployed at effectively zero cost for learning purposes, with the tradeoffs clearly documented in `cost-analysis.md`.

## 7. Challenges

- **NAT Gateway cost vs. Free Tier constraints** — Since NAT Gateway is not Free Tier eligible, an alternative NAT Instance path had to be designed, including handling the `source_dest_check` requirement and building a minimal `iptables` MASQUERADE configuration via `user_data`.
- **Security Group circular/ordered dependencies** — Referencing `bastion-sg` from `web-sg` and `private-sg` requires careful resource ordering; Terraform's implicit dependency graph resolves this automatically, but the equivalent manual AWS CLI/Console steps require the bastion SG to be created first.
- **NACL statelessness** — Unlike Security Groups, NACLs require explicit ephemeral port range rules (1024–65535) for return traffic, which is a common source of confusion and was documented explicitly in both the Terraform code and the README's NACL section.
- **AMI staleness** — Hardcoding an AMI ID would break the project over time as AMIs are deprecated; this was solved with a dynamic `aws_ami` data source lookup.

## 8. Solutions

Each challenge above was resolved as described: a conditional NAT Instance module for cost control, Terraform's dependency graph (and documented manual ordering) for security group references, explicit ephemeral-port NACL rules, and dynamic AMI lookups. These solutions are reflected directly in `terraform.tf` and cross-referenced in `README.md` and `cost-analysis.md`.

## 9. Future Scope

- Deploy a NAT Gateway **per Availability Zone** to remove the current single point of failure in the NAT layer.
- Add an **Application Load Balancer** in front of the public subnet(s) for true horizontal scalability.
- Introduce **VPC Flow Logs** and **CloudWatch/CloudTrail** integration for auditing and anomaly detection.
- Replace static EC2 web/app servers with an **Auto Scaling Group** and, longer-term, containerize workloads with **ECS/EKS**.
- Add **AWS Systems Manager Session Manager** as a bastion-less alternative for SSH access, removing the need for an internet-facing SSH endpoint entirely.
- Introduce a **remote Terraform backend** (S3 + DynamoDB locking) for team collaboration, already scaffolded (commented out) in `terraform.tf`.
- Add **AWS WAF** in front of the public web tier for common web-exploit protection.

## 10. Conclusion

This project demonstrates a complete, realistic, and well-documented AWS VPC architecture covering the full breadth of core networking concepts expected of a Cloud/DevOps Engineer: VPC and CIDR design, multi-AZ subnetting, Internet and NAT Gateways, route tables, layered security via Security Groups and NACLs, and secure bastion-based administrative access — all provisioned reproducibly via Terraform and documented thoroughly enough to serve as both a portfolio piece and an interview preparation resource.

## 11. References

- AWS VPC User Guide — <https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html>
- AWS Well-Architected Framework — <https://aws.amazon.com/architecture/well-architected/>
- Terraform AWS Provider Documentation — <https://registry.terraform.io/providers/hashicorp/aws/latest/docs>
- AWS Free Tier — <https://aws.amazon.com/free/>
- AWS NAT Gateway Documentation — <https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html>
