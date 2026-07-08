# 🧨 Destroy Guide — Safe Teardown Procedure

Deleting AWS networking resources out of order causes `DependencyViolation` errors and can leave **orphan resources** that silently continue billing you (Elastic IPs and NAT Gateways are the most common culprits). This guide explains how to tear down the project safely and completely, with both the Terraform and manual approaches.

---

## ⚠️ Before You Begin

- [ ] Back up anything on the EC2 instances you need (SSH in and `scp` files off first).
- [ ] Confirm you are destroying the correct AWS account/region — run `aws sts get-caller-identity` and `echo $AWS_REGION` first.
- [ ] Note that **Elastic IPs are billed if allocated but not attached to a running instance** — always release them.
- [ ] Note that a **NAT Gateway bills hourly even while Terraform is destroying other resources**, so destroy it early rather than last if doing a manual teardown.

---

## Option A: Terraform Destroy (Recommended)

```bash
cd Production-Style-AWS-VPC
terraform plan -destroy       # review what will be removed
terraform destroy             # type "yes" to confirm
```

Terraform automatically computes the correct dependency order (instances → NAT Gateway → EIPs → route tables → IGW → subnets → security groups → NACLs → VPC), so this is the safest and fastest option.

**Expected output (abridged):**
```
Destroy complete! Resources: 27 destroyed.
```

If `destroy` fails partway through (e.g. due to a manually-created dependency outside of Terraform's knowledge), re-run `terraform destroy` — it will pick up where it left off. Check `terraform state list` to see what still exists in state.

---

## Option B: Manual Console / CLI Teardown (Correct Order)

Follow this **exact order** to avoid `DependencyViolation` errors:

### 1. Terminate EC2 Instances
```bash
aws ec2 terminate-instances --instance-ids <bastion-id> <public-web-id> <private-app-id>
aws ec2 wait instance-terminated --instance-ids <bastion-id> <public-web-id> <private-app-id>
```
**Console:** EC2 → Instances → select all three → Instance State → Terminate.

### 2. Release Elastic IPs
```bash
aws ec2 disassociate-address --association-id <assoc-id>
aws ec2 release-address --allocation-id <bastion-eip-alloc-id>
aws ec2 release-address --allocation-id <nat-eip-alloc-id>
```
**Console:** VPC → Elastic IPs → select → Actions → Release Elastic IP addresses.

> ⚠️ **Warning:** An unattached Elastic IP is billed hourly. Always confirm zero Elastic IPs remain in **VPC → Elastic IPs** after teardown.

### 3. Delete the NAT Gateway
```bash
aws ec2 delete-nat-gateway --nat-gateway-id <nat-gateway-id>
aws ec2 wait nat-gateway-deleted --nat-gateway-ids <nat-gateway-id>
```
**Console:** VPC → NAT Gateways → select → Actions → Delete NAT gateway. Deletion takes 1–2 minutes.

> **Note:** You cannot release the associated Elastic IP until the NAT Gateway finishes deleting.

### 4. Delete Route Table Associations & Route Tables
```bash
aws ec2 disassociate-route-table --association-id <assoc-id>   # repeat for all 4 associations
aws ec2 delete-route-table --route-table-id <public-rt-id>
aws ec2 delete-route-table --route-table-id <private-rt-id>
```
**Console:** VPC → Route Tables → select the non-Main route tables → Actions → Delete route table (this also removes associations).

### 5. Detach and Delete the Internet Gateway
```bash
aws ec2 detach-internet-gateway --internet-gateway-id <igw-id> --vpc-id <vpc-id>
aws ec2 delete-internet-gateway --internet-gateway-id <igw-id>
```
**Console:** VPC → Internet Gateways → select → Actions → Detach from VPC, then Actions → Delete internet gateway.

### 6. Delete Subnets
```bash
aws ec2 delete-subnet --subnet-id <public-subnet-a-id>
aws ec2 delete-subnet --subnet-id <public-subnet-b-id>
aws ec2 delete-subnet --subnet-id <private-subnet-a-id>
aws ec2 delete-subnet --subnet-id <private-subnet-b-id>
```
**Console:** VPC → Subnets → select all four → Actions → Delete subnet.

### 7. Delete Security Groups
```bash
aws ec2 delete-security-group --group-id <bastion-sg-id>
aws ec2 delete-security-group --group-id <web-sg-id>
aws ec2 delete-security-group --group-id <private-sg-id>
```
**Console:** VPC → Security Groups → select all three (never delete `default`) → Actions → Delete security groups.

> **Note:** If a security group is referenced by another security group's rules (e.g. `web-sg` referencing `bastion-sg`), delete the *referencing* rules first, or simply delete in reverse creation order — Terraform handles this automatically, which is one more reason to prefer Option A.

### 8. Delete Network ACLs
```bash
aws ec2 delete-network-acl --network-acl-id <public-nacl-id>
aws ec2 delete-network-acl --network-acl-id <private-nacl-id>
```
**Console:** VPC → Network ACLs → select the custom NACLs (not `default`) → Actions → Delete network ACL. A NACL cannot be deleted while still associated with a subnet — subnets must be deleted first, or re-associated back to the default NACL.

### 9. Delete the Key Pair (optional, local cleanup)
```bash
aws ec2 delete-key-pair --key-name production-vpc-keypair
rm -f production-vpc-keypair.pem
```

### 10. Delete the VPC
```bash
aws ec2 delete-vpc --vpc-id <vpc-id>
```
**Console:** VPC → Your VPCs → select → Actions → Delete VPC (the Console version can also cascade-delete remaining dependent resources for you, but reviewing each step manually is safer for learning purposes).

---

## Final Verification — Confirm Zero Orphan Resources

Run these commands and confirm **empty results** for anything tagged with this project:

```bash
aws ec2 describe-addresses --query "Addresses[?Tags[?Value=='production-style-vpc-nat-eip' || Value=='production-style-vpc-bastion-eip']]"
aws ec2 describe-nat-gateways --filter "Name=tag:Project,Values=Production-Style-AWS-VPC" --query "NatGateways[?State!='deleted']"
aws ec2 describe-instances --filters "Name=tag:Project,Values=Production-Style-AWS-VPC" --query "Reservations[].Instances[?State.Name!='terminated']"
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=production-style-vpc-vpc"
```

Finally, check the **AWS Billing Dashboard → Bills** the next day to confirm no unexpected charges are accruing.

> 💡 **Tip:** Set up an **AWS Budget** alert (Billing → Budgets → Create budget) for $1–5/month while learning, so you get an email the moment any resource starts accruing unexpected cost.
