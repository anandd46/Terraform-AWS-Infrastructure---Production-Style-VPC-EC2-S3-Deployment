



# 🏗️ Production-Style AWS VPC Architecture

<p align="center">
  <img src="https://img.shields.io/badge/AWS-VPC-orange?logo=amazon-aws&logoColor=white" alt="AWS VPC">
  <img src="https://img.shields.io/badge/Terraform-1.6%2B-844FBA?logo=terraform&logoColor=white" alt="Terraform">
  <img src="https://img.shields.io/badge/IaC-Infrastructure%20as%20Code-blue" alt="IaC">
  <img src="https://img.shields.io/badge/Status-Production--Style-success" alt="Status">
  <img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT">
  <img src="https://img.shields.io/badge/Free%20Tier-Alternative%20Included-brightgreen" alt="Free Tier Alternative">
</p>

<p align="center">
  <b>A complete, multi-AZ, highly-available AWS VPC networking project</b><br>
  Built with Terraform · Documented like production · Interview-ready
</p>

---

## 📑 Table of Contents

- [Project Overview](#-project-overview)
- [Real-World Use Case](#-real-world-use-case)
- [Problem Statement](#-problem-statement)
- [Solution](#-solution)
- [Architecture Overview](#-architecture-overview)
- [Complete Network Topology](#-complete-network-topology)
- [CIDR Planning Table](#-cidr-planning-table)
- [Availability Zones](#-availability-zones)
- [Subnet Design](#-subnet-design)
- [Internet Gateway](#-internet-gateway)
- [NAT Gateway (and Free Tier Alternative)](#-nat-gateway-and-free-tier-alternative)
- [Route Tables & Route Propagation](#-route-tables--route-propagation)
- [Elastic IP](#-elastic-ip)
- [Security Groups](#-security-groups)
- [Network ACLs](#-network-acls)
- [Traffic Flow](#-traffic-flow)
- [Step-by-Step Deployment](#-step-by-step-deployment)
- [Testing & Verification](#-testing--verification)
- [Cleanup](#-cleanup)
- [Cost Estimation](#-cost-estimation)
- [Production Recommendations](#-production-recommendations)
- [Best Practices Applied](#-best-practices-applied)
- [Limitations](#-limitations)
- [Future Improvements](#-future-improvements)
- [Lessons Learned](#-lessons-learned)
- [Troubleshooting](#-troubleshooting)
- [Screenshots](#-screenshots)
- [Project Files](#-project-files)
- [Author](#-author)
- [License](#-license)
- [References](#-references)

---

## 🌐 Project Overview

**Production-Style AWS VPC Architecture** is a fully documented, Infrastructure-as-Code implementation of a realistic, enterprise-grade Amazon Virtual Private Cloud. It goes far beyond a "hello world" VPC tutorial — it demonstrates the complete set of networking primitives that underpin virtually every serious workload running on AWS: custom CIDR planning, multi-AZ high availability, public/private subnet segmentation, controlled internet egress, layered security (Security Groups **and** Network ACLs), and secure administrative access through a Bastion Host.

This project was built to be **portfolio-ready** and **interview-ready**. Every design decision below is explained, every file is production-quality, and the entire stack can be deployed with a single `terraform apply` — or manually, step by step, through the AWS Console or AWS CLI, all of which are documented in this repository.

### What Makes This "Production-Style"?

A huge number of tutorial VPC projects online stop at "create a VPC, create a subnet, launch an EC2 instance." This project deliberately goes further:

- **Realistic, non-trivial CIDR planning** with room for growth, not "whatever the console defaults to."
- **Two Availability Zones**, because a single-AZ design is not resilient and would never pass a real architecture review.
- **A genuine public/private split**, with the private tier fully isolated from direct internet access.
- **Defense-in-depth security**, combining stateful Security Groups with stateless Network ACLs — most tutorials only cover one.
- **A Bastion Host pattern**, the standard way production teams manage SSH access to private resources.
- **An honest cost conversation**, including a Free Tier-compatible alternative to the (non-Free-Tier) NAT Gateway.
- **Full Infrastructure as Code** using Terraform, plus equivalent AWS CLI and Console procedures for engineers who want to understand what's happening "under the hood."

---

## 🎯 Project Goals

1. Demonstrate mastery of core AWS networking concepts expected in Cloud/DevOps/SRE interviews.
2. Build a reusable, well-documented Terraform module that can be deployed to any AWS account in minutes.
3. Show an understanding of AWS cost structures, including how to avoid unnecessary spend.
4. Provide a genuinely useful reference — for the author's own future projects, and for anyone learning AWS networking from this repository.
5. Present all of the above with the polish and completeness expected of a professional engineering portfolio piece.

---

## 🏢 Real-World Use Case

Imagine a small-to-midsize SaaS company deploying its first production environment on AWS. They need:

- A public-facing web tier that customers can reach over HTTPS.
- An internal application/database tier that must **never** be directly reachable from the internet, to protect customer data.
- A way for engineers to SSH into internal servers for maintenance and debugging, without exposing SSH to the entire internet.
- Redundancy across data centers so that a single hardware failure or AZ outage doesn't take down the whole product.
- A security model with more than one layer of defense, so a single misconfiguration doesn't equal a full breach.

This project is a direct, deployable blueprint for exactly that scenario — the same pattern used (with additional scaling components) by companies running production workloads on AWS today.

---

## ❗ Problem Statement

Many engineers learning AWS jump straight from "what is EC2?" to launching instances in the default VPC with wide-open security groups. This creates several real problems:

1. **No network segmentation** — a compromised web server has a direct network path to sensitive internal systems.
2. **No planned IP address space** — ad hoc subnetting leads to painful re-architecture later as the environment grows.
3. **Overexposed administrative access** — SSH open to `0.0.0.0/0` is one of the most common causes of real-world AWS account compromise.
4. **Single points of failure** — deploying into a single AZ means an entire outage is one data-center event away.
5. **Cost surprises** — engineers unaware that NAT Gateways bill continuously often get an unpleasant billing surprise their first month.

## ✅ Solution

This project solves each problem above directly:

| Problem | Solution Implemented Here |
|---|---|
| No network segmentation | Explicit public/private subnet split with dedicated route tables |
| No IP planning | A deliberate, documented CIDR table with room to grow |
| Overexposed SSH | Bastion Host pattern + Security Groups scoped to a single admin IP or referencing SGs, never `0.0.0.0/0` for SSH |
| Single point of failure | Two Availability Zones, each with its own public and private subnet |
| Cost surprises | A dedicated `cost-analysis.md` with a documented, working Free Tier NAT alternative |

---

## 🏛️ Architecture Overview

The diagram below shows the complete architecture: a custom VPC spanning two Availability Zones, each with a public and private subnet, an Internet Gateway providing bidirectional access to the public tier, a NAT Gateway providing outbound-only access to the private tier, and a Bastion Host as the sole SSH entry point.

<img width="2880" height="1890" alt="architecture" src="https://github.com/user-attachments/assets/2c2bc08d-a900-4b83-8a28-323cf34131f7" />


**Key components at a glance:**

| Component | Purpose | Quantity |
|---|---|---|
| VPC | Isolated virtual network | 1 |
| Availability Zones | High availability | 2 |
| Public Subnets | Internet-facing resources | 2 (1 per AZ) |
| Private Subnets | Internal-only resources | 2 (1 per AZ) |
| Internet Gateway | Bidirectional internet access for public tier | 1 |
| NAT Gateway | Outbound-only internet access for private tier | 1 (or NAT Instance alternative) |
| Route Tables | Traffic routing rules | 2 (public, private) |
| Security Groups | Instance-level stateful firewall | 3 (bastion, web, private) |
| Network ACLs | Subnet-level stateless firewall | 2 (public, private) |
| EC2 Instances | Compute | 3 (bastion, public web, private app) |
| Elastic IP | Static public address | 1–2 (bastion, and NAT if using NAT Gateway) |

> 💡 **Tip:** Open `architecture.png` full-size while reading the rest of this README — every section below maps directly onto a labeled component in that diagram.

---

## 🗺️ Complete Network Topology

<img width="2700" height="1710" alt="vpc-topology" src="https://github.com/user-attachments/assets/1ea2079a-fa36-4f8b-9aa3-d5f2aadfc8f0" />


The VPC (`10.0.0.0/16`) is divided into four subnets, two per Availability Zone, following a consistent, memorable numbering convention: public subnets use the `.1.x`/`.2.x` ranges, private subnets use the `.11.x`/`.12.x` ranges. This convention makes it immediately obvious from an IP address alone which tier and which AZ a resource belongs to — a small detail that pays off enormously during incident response.

---

## 📐 CIDR Planning Table

| Subnet | CIDR Block | Availability Zone | Tier | Usable IPs | Purpose |
|---|---|---|---|---|---|
| VPC | `10.0.0.0/16` | (spans region) | — | 65,536 | Overall address space |
| Public Subnet A | `10.0.1.0/24` | us-east-1a | Public | 251 | Bastion Host, NAT Gateway, Public Web Server |
| Public Subnet B | `10.0.2.0/24` | us-east-1b | Public | 251 | Reserved for HA (second NAT GW / ALB nodes) |
| *(reserved)* | `10.0.3.0/24` – `10.0.10.0/24` | — | — | — | Reserved for future public subnets |
| Private Subnet A | `10.0.11.0/24` | us-east-1a | Private | 251 | Application/Database Server |
| Private Subnet B | `10.0.12.0/24` | us-east-1b | Private | 251 | Standby Application Server |
| *(reserved)* | `10.0.13.0/24` – `10.0.254.0/24` | — | — | — | Reserved for future private subnets, additional tiers (e.g., data tier), or Transit Gateway attachments |

> **Note:** AWS reserves 5 IP addresses in every subnet (network address, VPC router, DNS server, future use, and broadcast), which is why a `/24` subnet yields 251 usable addresses rather than 256.

> 💡 **Tip:** Notice the deliberate gap between `10.0.2.0/24` and `10.0.11.0/24`. This isn't an accident — it leaves 8 full `/24` blocks of headroom to add more public subnets (e.g., for a third AZ, or a dedicated transit/NAT subnet) without ever needing to renumber the private tier. This is exactly the kind of forward-thinking CIDR planning that separates a "toy" VPC from a production one.

---

## 🌍 Availability Zones

This project spans **two Availability Zones** (`us-east-1a` and `us-east-1b` by default, configurable via the `availability_zones` Terraform variable). Each AZ is a physically separate, independently-powered and independently-networked data center (or cluster of data centers) within the same AWS Region.

**Why two AZs, and not one or three?**

- **One AZ** provides zero resilience against a data-center-level failure — an outage there means total downtime.
- **Two AZs** is the minimum required for genuine high availability, and is the standard "starter" HA configuration used across almost all AWS reference architectures (including RDS Multi-AZ, which itself uses exactly two AZs).
- **Three or more AZs** further improves resilience and is common for larger production fleets, but adds proportional cost and complexity — this project uses two to balance realism with approachability, and the Terraform `availability_zones` variable can be extended to more AZs by anyone who wants to practice that extension.

---

## 🧱 Subnet Design

### Public Subnet

The public subnets (`10.0.1.0/24` and `10.0.2.0/24`) host resources that need to be directly reachable from, or need to directly reach, the public internet:

- The **Bastion Host** — the sole SSH entry point into the environment.
- The **NAT Gateway** — must live in a public subnet since it needs its own route to the Internet Gateway.
- The **Public Web Server** — serves HTTP/HTTPS traffic to any visitor.

Public subnets have `map_public_ip_on_launch` enabled, so any EC2 instance launched into them automatically receives a public IPv4 address, and their route table sends `0.0.0.0/0` traffic to the Internet Gateway.

### Private Subnet

The private subnets (`10.0.11.0/24` and `10.0.12.0/24`) host resources that should never be directly reachable from the internet:

- The **Private Application Server** — represents an internal app tier or database.

Private subnets have `map_public_ip_on_launch` disabled, and their route table sends `0.0.0.0/0` traffic to the NAT Gateway rather than the Internet Gateway — meaning they can initiate outbound connections (e.g., to download OS updates) but cannot receive unsolicited inbound connections from the internet.

---

## 🚪 Internet Gateway

The Internet Gateway (IGW) is a horizontally scaled, redundant, and highly available AWS-managed component that provides a target for internet-routable traffic in the public route table, and performs network address translation for instances that have been assigned public IPv4 addresses. There is exactly one IGW in this project, attached to the VPC, and it is entirely free to operate (you only pay for data transfer, not for the gateway itself).

```hcl
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "${local.name}-igw" }
}
```

---

## 🔀 NAT Gateway (and Free Tier Alternative)

### The Production Path: Managed NAT Gateway

By default (`enable_nat_gateway = true`), this project deploys an AWS-managed **NAT Gateway** in Public Subnet A, with an Elastic IP attached. The private route table sends all `0.0.0.0/0` traffic to this NAT Gateway, giving private instances outbound-only internet access — they can reach package repositories, APIs, etc., but the internet cannot initiate a connection back to them.

> ⚠️ **Warning:** NAT Gateway is **not** AWS Free Tier eligible. It bills approximately **$0.045/hour** (~$32/month) **plus** a per-GB data processing charge, regardless of how much traffic actually flows through it. See `cost-analysis.md` for full numbers.

### The Free Tier Alternative: NAT Instance

Because NAT Gateway is a real, ongoing cost, this project also implements and documents a **Free Tier-eligible NAT Instance** alternative. Set:

```hcl
enable_nat_gateway  = false
enable_nat_instance = true
```

in your `terraform.tfvars`, and Terraform will instead launch a `t2.micro` EC2 instance configured to perform NAT via IP forwarding and `iptables` MASQUERADE rules — all within Free Tier EC2 hours. The two critical requirements for a working NAT Instance are:

1. **Disabling the Source/Destination Check** (`source_dest_check = false`) — EC2 blocks traffic not addressed to/from an instance by default; a NAT instance must forward traffic on behalf of others, so this check must be turned off.
2. **Enabling IP forwarding and NAT rules** in the instance's `user_data`, which this project automates:

```bash
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
/sbin/iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
/sbin/iptables-save > /etc/sysconfig/iptables
```

**Trade-offs of the NAT Instance path** (documented honestly, not glossed over):
- It is a single EC2 instance — not automatically highly available or self-healing like a managed NAT Gateway.
- It requires you to manage OS patching yourself.
- Its throughput is limited to the chosen instance type's network performance (a `t2.micro` is fine for learning/demo traffic, not for production load).
- It's genuinely $0 (within Free Tier hour limits), making it the right choice for learning, demos, and portfolio deployments where you don't want a recurring bill.

### A Third Option: No NAT At All

For the absolute cheapest and most locked-down configuration, you can set `enable_nat_gateway = false` and `enable_nat_instance = false`. Private instances will then have **zero internet access** — appropriate for workloads that only need to talk to other resources inside the VPC or via VPC Endpoints (e.g., to S3), never to the open internet.

<img width="2700" height="1710" alt="routing-diagram" src="https://github.com/user-attachments/assets/e36ad866-cac1-46c9-8a63-f03fecff6b25" />


---

## 🛣️ Route Tables & Route Propagation

Two route tables are created:

**Public Route Table (`public-rt`)**

| Destination | Target |
|---|---|
| `10.0.0.0/16` | local |
| `0.0.0.0/0` | Internet Gateway |

**Private Route Table (`private-rt`)**

| Destination | Target |
|---|---|
| `10.0.0.0/16` | local |
| `0.0.0.0/0` | NAT Gateway (or NAT Instance) |

Each route table is explicitly associated with its corresponding subnets (both public subnets → `public-rt`; both private subnets → `private-rt`). This project does not rely on the VPC's default "main" route table for anything meaningful — explicit associations make the routing intent unambiguous and auditable, which matters enormously when troubleshooting connectivity issues months later.

> **Note on Route Propagation:** "Propagation" specifically refers to routes automatically learned from a Virtual Private Gateway or Transit Gateway attachment (e.g., for a Site-to-Site VPN or hybrid connectivity) and injected into a route table without manual entry. This project doesn't use VPN/Transit Gateway, so all routes here are manually defined — but the concept is documented in `interview-questions.md` since it's a common interview topic.

---

## 📌 Elastic IP

An Elastic IP (EIP) is a static, public IPv4 address you own for as long as you hold the allocation, regardless of whether the underlying instance is running, stopped, or replaced. This project uses Elastic IPs in two places:

1. **Attached to the NAT Gateway** (when `enable_nat_gateway = true`) — required by AWS; a NAT Gateway must have an EIP to relay traffic.
2. **Attached to the Bastion Host** — so that its public IP never changes across stop/start cycles, keeping your SSH config, firewall allow-lists, and DNS entries stable.

> ⚠️ **Warning:** An Elastic IP that is allocated but **not** attached to a running instance is billed hourly. Always release unused EIPs — see `destroy.md`.

---

## 🔒 Security Groups

Security Groups are **stateful** virtual firewalls attached at the instance (ENI) level. "Stateful" means that if inbound traffic is allowed on a port, the corresponding outbound response is automatically permitted — you don't need a matching outbound rule for replies.

<img width="2700" height="1710" alt="security-group-diagram" src="https://github.com/user-attachments/assets/fd4e604b-9eb7-4377-b010-a9999624ae11" />


| Security Group | Inbound Rules | Outbound Rules | Attached To |
|---|---|---|---|
| `bastion-sg` | TCP 22 from `admin_ip_cidr` only | All traffic | Bastion Host |
| `web-sg` | TCP 80, 443 from `0.0.0.0/0`; TCP 22 from `bastion-sg` | All traffic | Public Web Server |
| `private-sg` | TCP 22 from `bastion-sg`; TCP 3306 from `web-sg` | All traffic (routed via NAT) | Private Application Server |

**Design principle: Security-Group-to-Security-Group references, not IP ranges.** Notice that `web-sg` and `private-sg` don't grant SSH access to a hardcoded IP range — they reference `bastion-sg` directly. This means the rule automatically remains correct even if the bastion's IP address changes (e.g., after being replaced), and it self-documents the intended traffic flow: only the bastion may SSH anywhere else in this VPC.

> 🚫 **Never do this:** Opening SSH (port 22) to `0.0.0.0/0` on any Security Group. This is one of the single most common causes of real-world AWS compromise — automated internet scanners find open port 22 within minutes of it becoming reachable.

---

## 🧾 Network ACLs

Network ACLs (NACLs) are **stateless**, subnet-level firewalls evaluated in rule-number order, and — unlike Security Groups — they support explicit `DENY` rules in addition to `ALLOW` rules. Because they're stateless, return traffic (like the ephemeral ports used for HTTP responses) must be explicitly allowed.

**Public NACL (`public-nacl`)**

| Rule # | Direction | Protocol | Port Range | Source/Dest | Action |
|---|---|---|---|---|---|
| 100 | Inbound | TCP | 22 | `0.0.0.0/0` | ALLOW |
| 110 | Inbound | TCP | 80 | `0.0.0.0/0` | ALLOW |
| 120 | Inbound | TCP | 443 | `0.0.0.0/0` | ALLOW |
| 130 | Inbound | TCP | 1024–65535 | `0.0.0.0/0` | ALLOW (ephemeral return traffic) |
| 100 | Outbound | ALL | ALL | `0.0.0.0/0` | ALLOW |

**Private NACL (`private-nacl`)**

| Rule # | Direction | Protocol | Port Range | Source/Dest | Action |
|---|---|---|---|---|---|
| 100 | Inbound | ALL | ALL | `10.0.0.0/16` (VPC only) | ALLOW |
| 110 | Inbound | TCP | 1024–65535 | `0.0.0.0/0` | ALLOW (ephemeral return traffic) |
| 100 | Outbound | ALL | ALL | `0.0.0.0/0` | ALLOW |

> 💡 **Tip:** Security Groups and NACLs are **complementary, not redundant**. Security Groups protect individual instances (stateful, allow-only); NACLs protect entire subnets (stateless, ordered allow/deny). Using both is a textbook defense-in-depth pattern — this project deliberately uses both layers rather than relying on Security Groups alone.

---

## 🔁 Traffic Flow

<img width="2700" height="1620" alt="network-flow" src="https://github.com/user-attachments/assets/5cdbc9a3-584b-45d2-a254-4fe09b0e725e" />


### SSH Flow (Administrative Access)

1. Administrator's laptop initiates SSH to the **Bastion Host's Elastic IP** on port 22.
2. Traffic passes through the **Internet Gateway** into the **public subnet**, where `bastion-sg` verifies the source IP matches `admin_ip_cidr`.
3. From the bastion, the administrator initiates a second SSH hop (or a single `ssh -J` ProxyJump command) to the **private application server's private IP**.
4. `private-sg` verifies the source is `bastion-sg` before allowing the connection.

### Internet Traffic Flow (Public Web Request)

1. An end user's browser sends an HTTP/HTTPS request to the **Public Web Server's public IP**.
2. Traffic enters via the **Internet Gateway**, is checked against the **public NACL**, then against `web-sg` (allowing 80/443 from anywhere).
3. The web server processes and returns the response along the reverse path.

### Private Network Flow (Outbound-Only Internet Access)

1. The **private application server** needs to reach an external API or download an OS update.
2. Its outbound request is evaluated against the **private route table**, which sends `0.0.0.0/0` traffic to the **NAT Gateway** (in the public subnet).
3. The NAT Gateway translates the private source IP to its own Elastic IP and forwards the request through the **Internet Gateway**.
4. Return traffic follows the reverse path — but critically, the internet **cannot** initiate a new connection back to the private instance; only responses to connections it initiated are allowed back through.

---

## 🚀 Step-by-Step Deployment

Full instructions live in [`deployment-guide.md`](deployment-guide.md), but here's the condensed path using Terraform:

```bash
# 1. Clone and enter the project
git clone https://github.com/<your-username>/Production-Style-AWS-VPC.git
cd Production-Style-AWS-VPC

# 2. Configure your variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars: set admin_ip_cidr to YOUR public IP (curl https://checkip.amazonaws.com)

# 3. Create an EC2 key pair (must match key_pair_name in terraform.tfvars)
aws ec2 create-key-pair --key-name production-vpc-keypair \
  --query 'KeyMaterial' --output text > production-vpc-keypair.pem
chmod 400 production-vpc-keypair.pem

# 4. Initialize, plan, and apply
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

<details>
<summary><b>▶ Click to expand: AWS Console deployment (no Terraform)</b></summary>

1. **VPC → Create VPC** → name `production-vpc`, IPv4 CIDR `10.0.0.0/16`.
2. **Subnets → Create subnet** → create all 4 subnets per the [CIDR Planning Table](#-cidr-planning-table) above.
3. **Internet Gateways → Create internet gateway** → attach to `production-vpc`.
4. **NAT Gateways → Create NAT gateway** → place in Public Subnet A, allocate a new Elastic IP.
5. **Route Tables → Create route table** (x2) → add routes, then edit subnet associations for each.
6. **Security Groups → Create security group** (x3) → configure per the [Security Groups](#-security-groups) table.
7. **Network ACLs → Create network ACL** (x2) → configure per the [Network ACLs](#-network-acls) table, associate with subnets.
8. **EC2 → Launch instance** → launch the bastion, public web server, and private app server.
9. **Elastic IPs → Allocate Elastic IP address** → associate with the bastion instance.

Full details and exact screenshots to capture at each step: see [`deployment-guide.md`](deployment-guide.md) and [`screenshots.md`](screenshots.md).
</details>

<details>
<summary><b>▶ Click to expand: AWS CLI deployment (no Console, no Terraform)</b></summary>

The complete, explained command sequence lives in [`aws-cli-commands.md`](aws-cli-commands.md) — it covers creating the VPC, IGW, subnets, NAT Gateway, route tables, security groups, NACLs, key pair, and EC2 instances entirely via `aws ec2` commands, with an explanation of what each command does and why.
</details>

---

## 🧪 Testing & Verification

After deployment, verify everything works end to end:

```bash
# SSH to the bastion (replace with your Terraform output)
ssh -i production-vpc-keypair.pem ec2-user@$(terraform output -raw bastion_public_ip)

# From the bastion, hop into the private instance
ssh -i production-vpc-keypair.pem ec2-user@<private_app_private_ip>

# Confirm outbound internet access via NAT (run inside the private instance)
curl -s https://checkip.amazonaws.com
# Should print the NAT Gateway's Elastic IP, NOT the private instance's own IP

# Confirm the public web server responds
curl http://$(terraform output -raw public_web_public_ip)
```

Full verification checklist, including ping tests and route table inspection commands, is in [`deployment-guide.md`](deployment-guide.md#12-verification).

---

## 🧹 Cleanup

```bash
terraform destroy
```

For the safe, dependency-ordered manual teardown procedure (important if you deployed via Console/CLI instead of Terraform), see [`destroy.md`](destroy.md). It specifically calls out how to avoid orphaned Elastic IPs and NAT Gateways, which are the most common source of unexpected AWS bills after "finishing" a project.

---

## 💰 Cost Estimation

| Scenario | Approx. Monthly Cost | Notes |
|---|---|---|
| Full deployment with NAT Gateway | **~$32–58/month** | NAT Gateway (~$32/mo) dominates; EC2 often free under Free Tier |
| Free Tier NAT Instance alternative | **~$0/month** | Within Free Tier hour limits — see caveats in `cost-analysis.md` |
| No NAT (fully isolated private tier) | **$0/month** | Private tier has zero internet access |

Full breakdown, per-resource pricing, and cost-reduction tactics: [`cost-analysis.md`](cost-analysis.md).

> ⚠️ **Warning:** Always run `terraform destroy` (or the manual teardown in `destroy.md`) when you're done experimenting. A forgotten NAT Gateway is the single most common source of unexpected AWS charges for learners.

---

## 🏭 Production Recommendations

If adapting this project for a real production workload rather than a portfolio/learning exercise:

- Deploy **one NAT Gateway per Availability Zone** instead of a single shared one, removing the current AZ-level single point of failure.
- Front the public web tier with an **Application Load Balancer** and put web servers in an **Auto Scaling Group**.
- Replace bastion-based SSH with **AWS Systems Manager Session Manager** to eliminate the internet-facing SSH port entirely.
- Enable **VPC Flow Logs** shipped to CloudWatch Logs or S3 for auditing and anomaly detection.
- Move Terraform state to a **remote S3 + DynamoDB-locked backend** (already scaffolded, commented out, in `terraform.tf`).
- Add **AWS WAF** in front of the public tier for common web-exploit protection.
- Consider **AWS Config** rules to continuously audit that security groups/NACLs never drift into an insecure state.

---

## ✅ Best Practices Applied

- ✔️ Explicit, non-overlapping, forward-planned CIDR ranges
- ✔️ Multi-AZ subnet design for high availability
- ✔️ Least-privilege Security Group rules using SG-to-SG references instead of broad CIDR ranges
- ✔️ Defense-in-depth via both Security Groups and Network ACLs
- ✔️ No direct internet exposure for private/internal resources
- ✔️ Bastion Host pattern for controlled, auditable administrative access
- ✔️ Elastic IPs used only where a stable address is genuinely required
- ✔️ Consistent, meaningful resource naming and tagging conventions
- ✔️ Fully reproducible via Infrastructure as Code (Terraform)
- ✔️ Honest, documented cost trade-offs rather than hiding the NAT Gateway cost

---

## ⚠️ Limitations

- The default configuration uses a **single NAT Gateway** (not one per AZ), which is a documented, deliberate cost/complexity trade-off — not a full production-grade HA NAT design.
- EC2 instances in this project are standalone (no Auto Scaling Group / Load Balancer) — suitable for demonstrating networking concepts, not for demonstrating compute scalability patterns.
- The `admin_ip_cidr` default in `terraform.tfvars.example` is a placeholder and **must** be changed before applying, or SSH will not work as intended (or, if left as `0.0.0.0/0`, will be dangerously permissive).
- This project focuses on networking; it does not include application-layer concerns like a real database engine, application code, or CI/CD pipeline.

---

## 🔮 Future Improvements

- [ ] NAT Gateway per Availability Zone for full HA
- [ ] Application Load Balancer + Auto Scaling Group for the web tier
- [ ] AWS Systems Manager Session Manager instead of a Bastion Host
- [ ] VPC Flow Logs + CloudWatch/CloudTrail integration
- [ ] Remote Terraform backend (S3 + DynamoDB locking) enabled by default
- [ ] AWS WAF in front of the public tier
- [ ] Multi-region disaster recovery pattern
- [ ] Containerized workloads via ECS/EKS instead of standalone EC2

---

## 📚 Lessons Learned

Building this project reinforced several practical lessons that don't always come across in AWS documentation alone:

1. **CIDR planning done up front saves painful re-architecture later** — the temptation to "just use whatever the console suggests" is strong, but a few minutes of deliberate IP planning pays off enormously as an environment grows.
2. **NACLs are easy to misconfigure because of their statelessness** — forgetting the ephemeral port range is a rite of passage for anyone learning NACLs, and it produces a uniquely confusing symptom (outbound traffic leaves fine, but responses never arrive).
3. **Security-Group-to-Security-Group references are underused but extremely valuable** — they make security intent self-documenting and eliminate a whole category of "the IP changed and now the rule is wrong" bugs.
4. **The NAT Gateway's cost model surprises a lot of people** — it bills whether or not it's actively processing traffic, which matters a lot for cost-conscious learning/demo environments, hence this project's explicit Free Tier alternative.
5. **Infrastructure as Code makes teardown as important as setup** — with Terraform, both are one command, but understanding the manual dependency order (documented in `destroy.md`) makes you a much stronger troubleshooter when Terraform state gets out of sync with reality.

---

## 🛠️ Troubleshooting

See the full table in [`deployment-guide.md`](deployment-guide.md#15-troubleshooting) for common errors and fixes, covering IAM permission errors, SSH connection issues, NAT misconfiguration, and Terraform destroy ordering problems.

**Most common issues at a glance:**

| Symptom | Likely Fix |
|---|---|
| Can't SSH to bastion | Check `admin_ip_cidr` matches your *current* public IP |
| Private instance has no internet | Confirm `enable_nat_gateway=true` or the NAT instance alternative is enabled |
| `terraform destroy` fails with `DependencyViolation` | Re-run `terraform destroy`, or follow the manual order in `destroy.md` |
| Unexpected AWS bill | Check for a forgotten NAT Gateway or unattached Elastic IP |

---

## 📸 Screenshots

> Screenshot placeholders — capture these from your own deployment and embed them here. The full checklist of exactly what to capture (VPC, Subnets, Route Tables, IGW, NAT Gateway, Elastic IPs, Security Groups, NACLs, EC2, Instance Connect, ping results, SSH sessions, Terraform apply/output, and AWS CLI verification) is in [`screenshots.md`](screenshots.md).

```markdown
### VPC Overview
![VPC Overview](./screenshot-vpc-overview.png)

### Terraform Apply Success
![Terraform Apply](./screenshot-terraform-apply.png)

### SSH to Bastion Host
![SSH Bastion](./screenshot-ssh-bastion.png)
```

---

## 📁 Project Files

| File | Description |
|---|---|
| `README.md` | This file — complete project documentation |
| `LICENSE` | MIT License |
| `.gitignore` | Excludes state files, `.tfvars`, keys, and OS/editor junk from version control |
| `architecture.png` | Overall AWS architecture diagram |
| `vpc-topology.png` | Subnet layout and CIDR topology diagram |
| `routing-diagram.png` | Route tables and routing flow diagram |
| `network-flow.png` | SSH and internet traffic flow diagram |
| `security-group-diagram.png` | Security Group and NACL layering diagram |
| `deployment-guide.md` | Full step-by-step deployment instructions (Console, Terraform, CLI) |
| `aws-cli-commands.md` | Every AWS CLI command needed to build this manually, explained |
| `provider.tf` | Terraform AWS provider configuration |
| `terraform.tf` | Main Terraform resource definitions (VPC, subnets, gateways, SGs, NACLs, EC2) |
| `variables.tf` | All configurable Terraform input variables |
| `outputs.tf` | Terraform outputs (IPs, IDs, ready-to-use SSH commands) |
| `terraform.tfvars.example` | Example variable values to copy and customize |
| `destroy.md` | Safe, dependency-ordered resource teardown guide |
| `cost-analysis.md` | Full AWS cost breakdown and Free Tier guidance |
| `interview-questions.md` | 100+ AWS networking interview questions with answers |
| `project-report.md` | Formal project report (objectives, implementation, testing, results) |
| `screenshots.md` | Checklist of every Console screenshot to capture |

---

## 🧠 Skills Demonstrated

This project was built to showcase a broad, practical skill set relevant to Cloud Engineering, DevOps, and Site Reliability roles:

- **AWS Networking Fundamentals** — VPCs, subnets, CIDR planning, route tables, Internet and NAT Gateways, and the distinction between public and private network tiers.
- **Security Architecture** — designing layered, defense-in-depth controls using both stateful Security Groups and stateless Network ACLs, and applying least-privilege principles via Security-Group-to-Security-Group referencing rather than broad IP ranges.
- **High Availability Design** — deliberately spreading resources across multiple Availability Zones and documenting the remaining single points of failure honestly, along with concrete remediation paths.
- **Infrastructure as Code** — writing modular, readable, well-commented Terraform using data sources, dynamic blocks, conditional resource creation, and clean variable/output design.
- **Cost Engineering** — understanding AWS's pricing model well enough to identify the most expensive component in an architecture (the NAT Gateway) and design a genuine, working Free Tier alternative rather than just mentioning cost in passing.
- **Technical Documentation** — producing documentation thorough and structured enough to onboard a new engineer, support an interview conversation, or serve as an audit trail, spanning architecture diagrams, deployment guides, CLI references, and a formal project report.
- **Operational Discipline** — treating teardown/cleanup with the same rigor as deployment, since forgotten cloud resources are one of the most common real-world sources of both cost overruns and security exposure.

Together, these are the skills a hiring manager is actually trying to assess when a resume says "AWS networking experience" — this project is designed to make that experience concrete, demonstrable, and easy to discuss in depth during a technical interview.

---

## 👤 Author

**Cloud Engineering Portfolio Project**
Built to demonstrate production-style AWS networking, Infrastructure as Code, and professional technical documentation practices.

Feel free to fork this repository, deploy it into your own AWS account, and use it as a reference or a starting point for your own projects.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE) — free to use, modify, and distribute.

---

## 🔗 References & Useful AWS Documentation

- [Amazon VPC User Guide](https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html)
- [VPC NAT Gateways](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html)
- [Security Groups for Your VPC](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html)
- [Network ACLs](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-network-acls.html)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Free Tier](https://aws.amazon.com/free/)
- [AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/ec2/)

---

<p align="center">
  <i>⭐ If this project helped you understand AWS networking, consider starring the repository. ⭐</i>
</p>
