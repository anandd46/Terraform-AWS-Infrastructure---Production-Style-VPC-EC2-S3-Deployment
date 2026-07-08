# 💰 Cost Analysis

This document explains exactly what in this project costs money, what's covered by the AWS Free Tier, and how to minimize spend while still learning production-style networking patterns.

> **Disclaimer:** Prices below are approximate **us-east-1** on-demand rates and are illustrative only — AWS pricing changes over time and varies by region. Always confirm current pricing with the [AWS Pricing Calculator](https://calculator.aws/) before deploying.

---

## 1. AWS Free Tier Overview

The AWS Free Tier (12 months for new accounts, plus some "Always Free" services) includes, relevant to this project:

| Service | Free Tier Allowance |
|---|---|
| EC2 (t2.micro / t3.micro) | 750 hours/month for 12 months |
| EBS (gp2/gp3 storage) | 30 GB/month for 12 months |
| Elastic IP | Free **only** while attached to a running instance |
| Data Transfer Out | 100 GB/month (Always Free tier, first 12 months varies) |
| VPC itself (VPC, subnets, route tables, IGW, SGs, NACLs) | **Always free** — no charge for the networking constructs themselves |

## 2. What Is NOT Free Tier Eligible

| Resource | Why it costs money |
|---|---|
| **NAT Gateway** | Billed **hourly** (~$0.045/hr ≈ $32/month) **plus** ~$0.045 per GB processed, regardless of Free Tier status. This is the single most expensive component of this architecture. |
| **Elastic IP (unattached)** | ~$0.005/hr if allocated but not associated with a running instance — a common source of "surprise" AWS bills. |
| **EC2 instances beyond 750 hrs/month combined**, or non-`t2.micro`/`t3.micro` types | Billed per-second at the instance type's on-demand rate. |
| **Data transfer** beyond the free allowance | ~$0.09/GB out to the internet after the free 100 GB. |

---

## 3. Estimated Monthly Cost — Two Scenarios

### Scenario A: Full Production-Style Deployment (NAT Gateway enabled)

| Resource | Quantity | Est. Monthly Cost |
|---|---|---|
| NAT Gateway (hourly) | 1 | ~$32.40 |
| NAT Gateway data processing | ~5 GB | ~$0.23 |
| EC2 t2.micro (bastion) | 1 (730 hrs) | $0.00 (Free Tier) or ~$8.50 |
| EC2 t2.micro (public web) | 1 (730 hrs) | $0.00 (Free Tier) or ~$8.50 |
| EC2 t2.micro (private app) | 1 (730 hrs) | $0.00 (Free Tier) or ~$8.50 |
| Elastic IP (bastion, attached) | 1 | $0.00 |
| Elastic IP (NAT GW, attached) | 1 | $0.00 |
| EBS gp3 root volumes (3 x 8GB) | 24 GB | $0.00 (within 30GB Free Tier) |
| **TOTAL (within 12-month Free Tier, EC2 free)** | | **≈ $32.63/month** |
| **TOTAL (after Free Tier expires)** | | **≈ $58/month** |

> ⚠️ **Warning:** The NAT Gateway is the dominant cost in this architecture and is **not** Free Tier eligible under any circumstances. It bills whether or not traffic is flowing.

### Scenario B: Free Tier Alternative (NAT Instance instead of NAT Gateway)

Set `enable_nat_gateway = false` and `enable_nat_instance = true` in `terraform.tfvars`.

| Resource | Quantity | Est. Monthly Cost |
|---|---|---|
| NAT Instance (t2.micro, within Free Tier hours) | 1 | $0.00 |
| Bastion, Web, Private EC2 (t2.micro) | 3 | $0.00 (shares the same 750 free hrs pool — see note below) |
| Elastic IPs (attached) | 2 | $0.00 |
| EBS storage | ≤30 GB | $0.00 |
| **TOTAL** | | **≈ $0.00/month*** |

> \* **Important caveat:** The 750 free EC2 hours/month are **shared across all running t2.micro/t3.micro instances in your account**, not per-instance. Running 4 instances (bastion + web + private + NAT instance) simultaneously for a full month consumes 4 × 730 = 2,920 instance-hours, which **exceeds** the 750-hour pool. To stay fully within Free Tier: (a) only run this stack for short learning sessions and destroy it afterward, or (b) consolidate roles onto fewer instances, or (c) accept a small overage (a few dollars) for the extra hours beyond 750.

---

## 4. Cost Comparison Table

| Approach | Monthly Cost | Pros | Cons |
|---|---|---|---|
| **NAT Gateway** (Scenario A) | ~$32–58 | Fully managed, highly available, no patching, scales automatically | Not Free Tier eligible; most expensive line item |
| **NAT Instance** (Scenario B) | ~$0 (with caveats above) | Free Tier friendly, good for learning | Single point of failure, requires manual patching/scaling, must disable source/destination check |
| **No NAT at all** (private subnet fully isolated) | $0 | Cheapest, most secure (no egress path) | Private instances cannot download updates or reach external APIs |

---

## 5. Ways to Reduce Cost

1. **Destroy the stack when not actively using it.** `terraform destroy` takes seconds to tear down and `terraform apply` takes minutes to recreate — there's no reason to leave a NAT Gateway running 24/7 for a portfolio/demo project.
2. **Use the NAT Instance alternative** (`enable_nat_gateway = false`, `enable_nat_instance = true`) for learning and demos.
3. **Release all Elastic IPs** the moment they're not attached to a running resource — see `destroy.md`.
4. **Set an AWS Budget alert** at $1–5 so you're notified immediately of unexpected spend (Billing → Budgets).
5. **Stop (don't terminate) EC2 instances** between sessions if you want to preserve instance state — stopped instances don't bill for compute, only for attached EBS storage (a few cents/month for small volumes).
6. **Use a single NAT Gateway** shared across both AZs (as this project does) rather than one per AZ — the fully-HA pattern (one NAT Gateway per AZ) roughly doubles NAT cost and is a "future improvement" documented in the README rather than the default here.
7. **Monitor with Cost Explorer** (Billing → Cost Explorer) filtered by the `Project` tag applied to every resource in this stack.

---

## 6. Production Recommendation

For a **real production workload** (not a learning project), the NAT Gateway is almost always worth the cost given it eliminates an operational burden (patching, scaling, HA) that a self-managed NAT Instance would otherwise require. Combine it with:
- One NAT Gateway **per Availability Zone** (removes single point of failure — see README "Future Improvements")
- VPC Flow Logs for auditing (small additional CloudWatch Logs cost)
- Savings Plans / Reserved Instances for steady-state EC2 workloads to reduce compute cost 30–70%
