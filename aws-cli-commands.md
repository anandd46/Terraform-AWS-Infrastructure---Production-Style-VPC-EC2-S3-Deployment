# AWS CLI Command Reference

This document contains every AWS CLI command required to manually recreate the **Production-Style AWS VPC Architecture** without Terraform or the Console. Each command is explained so it can be used as a learning reference or a disaster-recovery runbook.

> **Prerequisite:** AWS CLI v2 installed and configured (`aws configure`) with an IAM user/role that has `AmazonVPCFullAccess` and `AmazonEC2FullAccess` (or equivalent least-privilege policy).

Set a few shell variables first so the rest of the commands can be copy-pasted as-is:

```bash
export AWS_REGION="us-east-1"
export AZ_A="us-east-1a"
export AZ_B="us-east-1b"
export PROJECT="production-style-vpc"
```

---

## 1. Create the VPC

```bash
aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=${PROJECT}-vpc}]" \
  --region $AWS_REGION
```
Creates the custom VPC with CIDR `10.0.0.0/16`. Note the returned `VpcId` and export it:

```bash
export VPC_ID=<vpc-xxxxxxxxx>

aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support "{\"Value\":true}"
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames "{\"Value\":true}"
```
Enables DNS resolution and DNS hostnames inside the VPC — required so EC2 instances get resolvable hostnames.

---

## 2. Create the Internet Gateway

```bash
aws ec2 create-internet-gateway \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=${PROJECT}-igw}]"
```
Creates an Internet Gateway (IGW), the component that allows resources in public subnets to reach the internet.

```bash
export IGW_ID=<igw-xxxxxxxxx>

aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID
```
Attaches the IGW to the VPC. An IGW is useless until attached.

---

## 3. Create Subnets

```bash
aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 \
  --availability-zone $AZ_A \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PROJECT}-public-subnet-1},{Key=Tier,Value=Public}]"

aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 \
  --availability-zone $AZ_B \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PROJECT}-public-subnet-2},{Key=Tier,Value=Public}]"

aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.11.0/24 \
  --availability-zone $AZ_A \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PROJECT}-private-subnet-1},{Key=Tier,Value=Private}]"

aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.12.0/24 \
  --availability-zone $AZ_B \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PROJECT}-private-subnet-2},{Key=Tier,Value=Private}]"
```
Creates two public and two private subnets spread across two Availability Zones for high availability. Export each returned `SubnetId` (e.g. `PUB_SUBNET_A`, `PUB_SUBNET_B`, `PRIV_SUBNET_A`, `PRIV_SUBNET_B`).

Enable auto-assign public IPs on the public subnets:

```bash
aws ec2 modify-subnet-attribute --subnet-id $PUB_SUBNET_A --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id $PUB_SUBNET_B --map-public-ip-on-launch
```
Instances launched in these subnets automatically receive a public IP.

---

## 4. Allocate an Elastic IP and Create the NAT Gateway

```bash
aws ec2 allocate-address --domain vpc \
  --tag-specifications "ResourceType=elastic-ip,Tags=[{Key=Name,Value=${PROJECT}-nat-eip}]"
```
Reserves a static public IPv4 address (Elastic IP). Export `AllocationId` as `EIP_ALLOC_ID`.

```bash
aws ec2 create-nat-gateway \
  --subnet-id $PUB_SUBNET_A \
  --allocation-id $EIP_ALLOC_ID \
  --tag-specifications "ResourceType=natgateway,Tags=[{Key=Name,Value=${PROJECT}-nat-gw}]"
```
Creates the NAT Gateway inside a **public** subnet. It uses the Elastic IP so private-subnet traffic can reach the internet while remaining unreachable from it. **NAT Gateway is billed hourly + per-GB — see `cost-analysis.md` for the Free Tier alternative.**

```bash
aws ec2 wait nat-gateway-available --nat-gateway-ids <nat-xxxxxxxxx>
```
Waits until the NAT Gateway is fully provisioned before continuing (usually 1–5 minutes).

---

## 5. Create Route Tables

```bash
aws ec2 create-route-table --vpc-id $VPC_ID \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${PROJECT}-public-rt}]"

aws ec2 create-route-table --vpc-id $VPC_ID \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${PROJECT}-private-rt}]"
```
Export the returned `RouteTableId`s as `PUB_RT_ID` and `PRIV_RT_ID`.

```bash
aws ec2 create-route --route-table-id $PUB_RT_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID
```
Adds the default route that sends all outbound public-subnet traffic to the Internet Gateway.

```bash
aws ec2 create-route --route-table-id $PRIV_RT_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id <nat-xxxxxxxxx>
```
Adds the default route that sends all outbound private-subnet traffic through the NAT Gateway.

---

## 6. Associate Route Tables with Subnets

```bash
aws ec2 associate-route-table --route-table-id $PUB_RT_ID --subnet-id $PUB_SUBNET_A
aws ec2 associate-route-table --route-table-id $PUB_RT_ID --subnet-id $PUB_SUBNET_B
aws ec2 associate-route-table --route-table-id $PRIV_RT_ID --subnet-id $PRIV_SUBNET_A
aws ec2 associate-route-table --route-table-id $PRIV_RT_ID --subnet-id $PRIV_SUBNET_B
```
Without an explicit association, a subnet uses the VPC's main (default) route table — associating explicitly makes routing intent clear and auditable.

---

## 7. Create Security Groups

```bash
aws ec2 create-security-group --group-name bastion-sg \
  --description "SSH access from admin IP only" --vpc-id $VPC_ID
```
Export `GroupId` as `BASTION_SG_ID`.

```bash
aws ec2 authorize-security-group-ingress --group-id $BASTION_SG_ID \
  --protocol tcp --port 22 --cidr <YOUR_IP>/32
```
Allows inbound SSH **only** from your own IP address — never leave SSH open to `0.0.0.0/0`.

```bash
aws ec2 create-security-group --group-name web-sg \
  --description "HTTP/HTTPS from internet, SSH from bastion" --vpc-id $VPC_ID

aws ec2 authorize-security-group-ingress --group-id $WEB_SG_ID --protocol tcp --port 80  --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $WEB_SG_ID --protocol tcp --port 443 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $WEB_SG_ID --protocol tcp --port 22  --source-group $BASTION_SG_ID
```
Public web tier accepts HTTP/HTTPS from anyone, but SSH only from the bastion's security group (a security-group reference, not an IP — this remains valid even if the bastion's IP changes).

```bash
aws ec2 create-security-group --group-name private-sg \
  --description "SSH from bastion, DB traffic from web tier" --vpc-id $VPC_ID

aws ec2 authorize-security-group-ingress --group-id $PRIVATE_SG_ID --protocol tcp --port 22   --source-group $BASTION_SG_ID
aws ec2 authorize-security-group-ingress --group-id $PRIVATE_SG_ID --protocol tcp --port 3306 --source-group $WEB_SG_ID
```
Private tier only accepts SSH from the bastion and database traffic from the web tier — a textbook least-privilege, defense-in-depth setup.

---

## 8. Create Network ACLs

```bash
aws ec2 create-network-acl --vpc-id $VPC_ID \
  --tag-specifications "ResourceType=network-acl,Tags=[{Key=Name,Value=${PROJECT}-public-nacl}]"
```
Export `NetworkAclId` as `PUB_NACL_ID`.

```bash
aws ec2 create-network-acl-entry --network-acl-id $PUB_NACL_ID --ingress \
  --rule-number 100 --protocol tcp --port-range From=22,To=22 --cidr-block 0.0.0.0/0 --rule-action allow

aws ec2 create-network-acl-entry --network-acl-id $PUB_NACL_ID --ingress \
  --rule-number 110 --protocol tcp --port-range From=80,To=80 --cidr-block 0.0.0.0/0 --rule-action allow

aws ec2 create-network-acl-entry --network-acl-id $PUB_NACL_ID --ingress \
  --rule-number 120 --protocol tcp --port-range From=443,To=443 --cidr-block 0.0.0.0/0 --rule-action allow

aws ec2 create-network-acl-entry --network-acl-id $PUB_NACL_ID --ingress \
  --rule-number 130 --protocol tcp --port-range From=1024,To=65535 --cidr-block 0.0.0.0/0 --rule-action allow

aws ec2 create-network-acl-entry --network-acl-id $PUB_NACL_ID --egress \
  --rule-number 100 --protocol -1 --cidr-block 0.0.0.0/0 --rule-action allow
```
NACLs are **stateless** — return traffic (e.g. ephemeral ports 1024–65535) must be explicitly allowed, unlike Security Groups, which are stateful.

```bash
aws ec2 replace-network-acl-association --association-id <assoc-id-for-public-subnet> --network-acl-id $PUB_NACL_ID
```
Associates the custom NACL with the public subnets (repeat per subnet, using `describe-network-acls` to find current association IDs).

*(Repeat similarly for a `private-nacl` restricting ingress to the VPC CIDR only.)*

---

## 9. Create a Key Pair

```bash
aws ec2 create-key-pair --key-name production-vpc-keypair \
  --query 'KeyMaterial' --output text > production-vpc-keypair.pem

chmod 400 production-vpc-keypair.pem
```
Generates an SSH key pair and saves the private key locally with the correct restrictive permissions required by SSH.

---

## 10. Launch EC2 Instances

```bash
export AMI_ID=$(aws ec2 describe-images --owners amazon \
  --filters "Name=name,Values=al2023-ami-*-x86_64" "Name=state,Values=available" \
  --query "sort_by(Images, &CreationDate)[-1].ImageId" --output text)
```
Dynamically looks up the latest Amazon Linux 2023 AMI ID instead of hardcoding a region-specific value.

```bash
aws ec2 run-instances --image-id $AMI_ID --instance-type t2.micro \
  --key-name production-vpc-keypair --subnet-id $PUB_SUBNET_A \
  --security-group-ids $BASTION_SG_ID --associate-public-ip-address \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${PROJECT}-bastion-host}]"
```
Launches the **Bastion Host** in the public subnet.

```bash
aws ec2 run-instances --image-id $AMI_ID --instance-type t2.micro \
  --key-name production-vpc-keypair --subnet-id $PUB_SUBNET_A \
  --security-group-ids $WEB_SG_ID --associate-public-ip-address \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${PROJECT}-public-web}]"
```
Launches the **public web server**.

```bash
aws ec2 run-instances --image-id $AMI_ID --instance-type t2.micro \
  --key-name production-vpc-keypair --subnet-id $PRIV_SUBNET_A \
  --security-group-ids $PRIVATE_SG_ID \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${PROJECT}-private-app}]"
```
Launches the **private application server** (no public IP — reachable only from inside the VPC).

---

## 11. Allocate & Associate an Elastic IP with the Bastion Host

```bash
aws ec2 allocate-address --domain vpc \
  --tag-specifications "ResourceType=elastic-ip,Tags=[{Key=Name,Value=${PROJECT}-bastion-eip}]"

aws ec2 associate-address --instance-id <bastion-instance-id> --allocation-id <bastion-eip-alloc-id>
```
Gives the bastion a static public IP so it doesn't change on stop/start, keeping your SSH config and firewall rules stable.

---

## 12. Verification Commands

```bash
aws ec2 describe-vpcs --vpc-ids $VPC_ID
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID"
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID"
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID"
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID"
aws ec2 describe-network-acls --filters "Name=vpc-id,Values=$VPC_ID"
aws ec2 describe-instances --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "Reservations[].Instances[].{ID:InstanceId,State:State.Name,PrivateIP:PrivateIpAddress,PublicIP:PublicIpAddress}"
```
Confirms every component was created correctly and shows current instance state/IP addresses.

### Test SSH connectivity

```bash
ssh -i production-vpc-keypair.pem ec2-user@<bastion-public-ip>

# From inside the bastion, hop to the private instance:
ssh -i production-vpc-keypair.pem ec2-user@<private-instance-ip>

# Or in a single command from your local machine using ProxyJump:
ssh -i production-vpc-keypair.pem -J ec2-user@<bastion-public-ip> ec2-user@<private-instance-ip>
```

### Test internet connectivity from the private instance (via NAT)

```bash
# Run this once SSH'd into the private instance:
curl -s https://checkip.amazonaws.com
ping -c 3 8.8.8.8
```
If this returns the **NAT Gateway's** Elastic IP (not the private instance's own IP), routing through the NAT Gateway is working correctly.

---

## 13. Cleanup / Termination Commands

See `destroy.md` for the full, safely-ordered teardown procedure. A quick reference:

```bash
aws ec2 terminate-instances --instance-ids <id1> <id2> <id3>
aws ec2 wait instance-terminated --instance-ids <id1> <id2> <id3>
aws ec2 delete-nat-gateway --nat-gateway-id <nat-id>
aws ec2 wait nat-gateway-deleted --nat-gateway-ids <nat-id>
aws ec2 release-address --allocation-id <eip-alloc-id>
aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID
aws ec2 delete-subnet --subnet-id <subnet-id>   # repeat for all 4
aws ec2 delete-route-table --route-table-id <rt-id>   # repeat for both
aws ec2 delete-security-group --group-id <sg-id>   # repeat for all 3
aws ec2 delete-network-acl --network-acl-id <nacl-id>   # repeat for both
aws ec2 delete-vpc --vpc-id $VPC_ID
```

> **Tip:** Resources must be deleted in reverse-dependency order (instances → NAT Gateway → EIP → IGW → subnets → route tables → security groups → NACLs → VPC), or AWS will reject the deletion with a `DependencyViolation` error.
