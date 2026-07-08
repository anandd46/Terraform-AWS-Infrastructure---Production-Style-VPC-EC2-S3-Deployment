# 🚀 Deployment Guide — Production-Style AWS VPC Architecture

This guide walks you through deploying the entire project from a completely blank AWS account, end to end, using **Terraform** (recommended) or the **AWS Console** as a manual alternative. Follow it top to bottom the first time.

## Table of Contents

1. [Create an AWS Account](#1-create-an-aws-account)
2. [Create an IAM User](#2-create-an-iam-user)
3. [Install the AWS CLI](#3-install-the-aws-cli)
4. [Install Terraform](#4-install-terraform)
5. [Set Up VS Code](#5-set-up-vs-code)
6. [Configure AWS Credentials](#6-configure-aws-credentials)
7. [Clone / Prepare the Project](#7-clone--prepare-the-project)
8. [Create an EC2 Key Pair](#8-create-an-ec2-key-pair)
9. [Terraform Init](#9-terraform-init)
10. [Terraform Plan](#10-terraform-plan)
11. [Terraform Apply](#11-terraform-apply)
12. [Verification](#12-verification)
13. [Manual AWS Console Deployment](#13-manual-aws-console-deployment-alternative)
14. [Destroy / Cleanup](#14-destroy--cleanup)
15. [Troubleshooting](#15-troubleshooting)
16. [Expected Output](#16-expected-output)

---

## 1. Create an AWS Account

1. Go to <https://aws.amazon.com/> and click **Create an AWS Account**.
2. Provide an email address, password, and AWS account name.
3. Enter billing information (a credit/debit card is required even for Free Tier usage).
4. Verify your identity via phone/SMS.
5. Choose the **Basic Support Plan** (free).

> ⚠️ **Warning:** AWS requires a valid payment method even for Free Tier resources. This project is designed to stay within Free Tier limits when `enable_nat_gateway = false`, but you are responsible for monitoring your own billing dashboard.

---

## 2. Create an IAM User

Never use your AWS **root account** for daily work.

1. Sign in to the [IAM Console](https://console.aws.amazon.com/iam/).
2. Navigate to **Users → Create user**.
3. Name it `cloud-engineer` (or similar).
4. Attach the policy **AdministratorAccess** for learning/lab purposes (in real production, scope this down to `AmazonVPCFullAccess` + `AmazonEC2FullAccess`).
5. Create an **Access Key** (CLI use case) and download the `.csv` credentials file.
6. Enable **MFA** on both the root account and this IAM user.

> 💡 **Tip:** Least privilege is a core AWS Well-Architected pillar. In real production environments, define a custom IAM policy scoped only to the actions this project needs.

---

## 3. Install the AWS CLI

**macOS:**
```bash
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /
```

**Linux:**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

**Windows:**
Download and run the MSI installer from <https://awscli.amazonaws.com/AWSCLIV2.msi>.

Verify installation:
```bash
aws --version
# aws-cli/2.x.x Python/3.x.x ...
```

---

## 4. Install Terraform

**macOS (Homebrew):**
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

**Linux:**
```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

**Windows (Chocolatey):**
```powershell
choco install terraform
```

Verify installation:
```bash
terraform -version
# Terraform v1.6.x or later
```

---

## 5. Set Up VS Code

1. Download [VS Code](https://code.visualstudio.com/).
2. Install extensions:
   - **HashiCorp Terraform** (syntax highlighting, validation, autocomplete)
   - **AWS Toolkit**
   - **YAML** / **markdownlint** (optional, for docs)
3. Open the project folder: `File → Open Folder → Production-Style-AWS-VPC`.

---

## 6. Configure AWS Credentials

```bash
aws configure
```
You will be prompted for:
```
AWS Access Key ID [None]: AKIA********************
AWS Secret Access Key [None]: ****************************************
Default region name [None]: us-east-1
Default output format [None]: json
```

Verify it worked:
```bash
aws sts get-caller-identity
```
Expected output:
```json
{
    "UserId": "AIDAxxxxxxxxxxxxxxxxx",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/cloud-engineer"
}
```

---

## 7. Clone / Prepare the Project

```bash
git clone https://github.com/<your-username>/Production-Style-AWS-VPC.git
cd Production-Style-AWS-VPC
```

Copy the example variables file and edit it:
```bash
cp terraform.tfvars.example terraform.tfvars
```

Find your public IP (required to lock down bastion SSH access):
```bash
curl https://checkip.amazonaws.com
```
Update `admin_ip_cidr` in `terraform.tfvars` with `<your-ip>/32`.

> ⚠️ **Warning:** Never leave `admin_ip_cidr` as `0.0.0.0/0` in a real deployment — this opens SSH to the entire internet.

---

## 8. Create an EC2 Key Pair

```bash
aws ec2 create-key-pair --key-name production-vpc-keypair \
  --query 'KeyMaterial' --output text > production-vpc-keypair.pem
chmod 400 production-vpc-keypair.pem
```

Make sure `key_pair_name` in `terraform.tfvars` matches the name you used here (`production-vpc-keypair` by default).

---

## 9. Terraform Init

```bash
terraform init
```
Downloads the AWS provider plugin and initializes the working directory / backend.

**Expected output (abridged):**
```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.x.x...
Terraform has been successfully initialized!
```

---

## 10. Terraform Plan

```bash
terraform plan -out=tfplan
```
Shows exactly what Terraform will create, without making any changes yet. Review it carefully — you should see approximately 25–30 resources to add (VPC, 4 subnets, IGW, NAT Gateway, EIP x2, 2 route tables, 4 route table associations, 2 NACLs, 3 security groups, 3 EC2 instances).

> 💡 **Tip:** Always run `terraform plan` before `apply`. Treat plan output like a pull-request diff for your infrastructure.

---

## 11. Terraform Apply

```bash
terraform apply tfplan
```
Or, without a saved plan file:
```bash
terraform apply
```
Type `yes` when prompted. This typically takes **3–6 minutes** (NAT Gateway provisioning is the slowest step).

**Expected output (abridged):**
```
Apply complete! Resources: 27 added, 0 changed, 0 destroyed.

Outputs:

bastion_public_ip = "54.xxx.xxx.xxx"
nat_gateway_public_ip = "3.xxx.xxx.xxx"
private_app_private_ip = "10.0.11.xxx"
public_web_public_ip = "54.xxx.xxx.xxx"
ssh_to_bastion_command = "ssh -i production-vpc-keypair.pem ec2-user@54.xxx.xxx.xxx"
vpc_id = "vpc-0abcd1234efgh5678"
```

---

## 12. Verification

### 12.1 Confirm resources in AWS Console
Navigate to **VPC → Your VPCs**, **Subnets**, **Route Tables**, **Internet Gateways**, **NAT Gateways**, **Security Groups**, **Network ACLs**, and **EC2 → Instances**. Confirm all resources match the Terraform outputs.

### 12.2 SSH to the Bastion Host
```bash
ssh -i production-vpc-keypair.pem ec2-user@$(terraform output -raw bastion_public_ip)
```

### 12.3 SSH from Bastion to Private Instance
```bash
ssh -i production-vpc-keypair.pem ec2-user@<private_app_private_ip>
```
Or directly from your laptop using ProxyJump:
```bash
terraform output ssh_to_private_via_bastion_command
```

### 12.4 Test Outbound Internet from Private Instance (via NAT)
From inside the private instance:
```bash
curl -s https://checkip.amazonaws.com
```
This should print the **NAT Gateway's Elastic IP**, confirming the private subnet correctly routes outbound traffic through the NAT Gateway while remaining unreachable from the internet.

### 12.5 Test the Public Web Server
```bash
curl http://$(terraform output -raw public_web_public_ip)
```
Should return the HTML placeholder page served by Apache (installed via `user_data`).

### 12.6 Test Ping Between Subnets
From the bastion, ping the private instance's private IP to confirm intra-VPC routing:
```bash
ping -c 3 <private_app_private_ip>
```

---

## 13. Manual AWS Console Deployment (Alternative)

If you prefer clicking through the Console instead of Terraform:

1. **VPC → Create VPC** → name `production-vpc`, CIDR `10.0.0.0/16`.
2. **Subnets → Create subnet** → create 4 subnets per the CIDR table in `README.md`.
3. **Internet Gateways → Create** → attach to the VPC.
4. **NAT Gateways → Create** → place in Public Subnet A, allocate a new Elastic IP.
5. **Route Tables → Create** → create `public-rt` and `private-rt`, add routes, then **Edit subnet associations**.
6. **Security Groups → Create** → create `bastion-sg`, `web-sg`, `private-sg` with the rules documented in `README.md`.
7. **Network ACLs → Create** → create `public-nacl` and `private-nacl`, add rules, associate with subnets.
8. **EC2 → Launch Instance** → launch the bastion, public web server, and private app server using the key pair and security groups created above.
9. **Elastic IPs → Allocate** → associate one with the bastion instance.

See `screenshots.md` for the exact screenshot to capture at each of these steps.

---

## 14. Destroy / Cleanup

See the dedicated [`destroy.md`](destroy.md) file for the complete, safe teardown procedure. Quick version with Terraform:

```bash
terraform destroy
```
Type `yes` when prompted. Always run `terraform plan -destroy` first if you want to review what will be removed.

---

## 15. Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| `UnauthorizedOperation` on `apply` | IAM user lacks required permissions | Attach `AmazonVPCFullAccess` + `AmazonEC2FullAccess`, or `AdministratorAccess` for labs |
| `terraform init` fails to download provider | No internet access / corporate proxy | Configure `HTTPS_PROXY` env var or check firewall |
| SSH `Connection timed out` to bastion | Security group doesn't allow your current IP | Re-check `admin_ip_cidr` matches your current public IP (`curl https://checkip.amazonaws.com`) |
| SSH `Permission denied (publickey)` | Wrong `.pem` file or wrong username | Amazon Linux uses `ec2-user`, Ubuntu AMIs use `ubuntu` |
| Private instance has no internet access | NAT Gateway missing/misconfigured, or `enable_nat_gateway=false` with no NAT instance | Confirm `enable_nat_gateway = true` in `terraform.tfvars` or enable the NAT instance alternative |
| `DependencyViolation` on `destroy` | Resources deleted out of order | Let `terraform destroy` handle ordering; for manual cleanup, follow `destroy.md` exactly |
| High/unexpected AWS bill | NAT Gateway left running | NAT Gateway bills **hourly + per-GB** even when idle — destroy it when not needed, or use the Free Tier NAT Instance alternative |
| `InvalidKeyPair.NotFound` | Key pair name mismatch | Ensure `key_pair_name` variable matches the key pair name in your AWS account/region exactly |

---

## 16. Expected Output

After a successful deployment you should have:

- ✅ 1 custom VPC (`10.0.0.0/16`)
- ✅ 4 subnets across 2 AZs (2 public, 2 private)
- ✅ 1 Internet Gateway (attached)
- ✅ 1 NAT Gateway + 1 Elastic IP (or NAT Instance if using the Free Tier path)
- ✅ 2 route tables with 4 associations
- ✅ 3 security groups (bastion, web, private)
- ✅ 2 Network ACLs
- ✅ 3 EC2 instances (bastion, public web, private app)
- ✅ 1 Elastic IP attached to the bastion
- ✅ Verified SSH access via bastion, verified outbound NAT connectivity, verified HTTP access to the public web server

Proceed to `screenshots.md` to document your working deployment for your portfolio/GitHub README.
