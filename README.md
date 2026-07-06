# Three-Tier Web Application on AWS (Terraform)

A production-style 3-tier architecture — Application Load Balancer → Auto Scaling EC2 web tier → private PostgreSQL RDS — provisioned entirely with Terraform and deployed through a GitHub Actions CI/CD pipeline.

## Problem Statement

A startup-style web application needs to run on AWS with proper high availability, least-privilege security, and zero manual console configuration — so any team member can rebuild the entire environment from git in under 30 minutes, and no single point of failure exists in the network or compute layer.

## Architecture

                                   Internet
                                       │
                                       ▼
                    ┌────────────────────────────────┐
                    │        Route 53 / ALB          │
                    │         (Public Layer)         │
                    │  SG: Allow 80/443 from Anywhere│
                    │         (0.0.0.0/0)            │
                    └──────────────┬─────────────────┘
                                   │
                                   ▼
                  ┌────────────────┴─────────────────┐
                  │      Auto Scaling Group          │
                  │          Min: 2 Instances        │
                  └────────────┬────────────┬────────┘
                               │            │
                               ▼            ▼
              ┌────────────────────┐ ┌────────────────────┐
              │     EC2 - AZ A     │ │     EC2 - AZ B     │
              │   Public Subnet A  │ │   Public Subnet B  │
              │                    │ │                    │
              │ SG: Allow 80 only  │ │ SG: Allow 80 only  │
              │     from ALB-SG    │ │     from ALB-SG    │
              └─────────┬──────────┘ └─────────┬──────────┘
                        │                      │
                        └──────────┬───────────┘
                                   │
                                   ▼
                    ┌────────────────────────────────┐
                    │        RDS PostgreSQL          │
                    │         Database Layer         │
                    │      Private Subnet(s)         │
                    │        Single-AZ Setup         │
                    │ SG: Allow 5432 from EC2-SG     │
                    └────────────────────────────────┘

*(See `architecture/diagram.png` for a visual version — see Section "Diagram" below.)*

## AWS Services Used

| Service | Purpose |
|---|---|
| VPC (2 AZs, public + private subnets) | Network isolation and high-availability foundation |
| Internet Gateway + Route Table | Public internet access for the web tier only |
| Security Groups (ALB, EC2, RDS) | Least-privilege network access, chained by security-group-as-source |
| Application Load Balancer | Public entry point, health-checked routing |
| Auto Scaling Group + Launch Template | Self-healing, horizontally scalable web tier |
| IAM Role + Instance Profile | Keyless EC2 access via SSM Session Manager (no SSH, no open port 22) |
| RDS (PostgreSQL, Single-AZ) | Private, least-privilege application database |
| S3 + DynamoDB-free native locking | Remote Terraform state, shared between local and CI |
| GitHub Actions | Automated `plan` on PR, `apply` on merge to `main` |

## How to Deploy

**Prerequisites:** Terraform ≥ 1.9, AWS CLI configured, an AWS account.

```bash
git clone https://github.com/Mus7ab/three-tier-webapp.git
cd three-tier-webapp/terraform

# Create your own terraform.tfvars (never committed - see .gitignore)
echo 'db_password = "YourOwnSecurePassword123!"' > terraform.tfvars

terraform init
terraform plan
terraform apply
```

CI/CD: any push to a feature branch + PR into `main` automatically runs `terraform plan`. Merging to `main` automatically runs `terraform apply`, using credentials scoped to a dedicated `github-actions-terraform` IAM user (not a personal admin account).

## Design Decisions

**Private RDS, not public.** `publicly_accessible = false` combined with private subnet placement and a security group that only trusts the EC2 tier's security group as a source. This is deliberate defense-in-depth: even if one layer were misconfigured later, the others still hold.

**Chained least-privilege security groups (ALB → EC2 → RDS).** Each security group references the *previous* one as its allowed source, rather than broad CIDR ranges. This makes it structurally impossible to bypass the ALB and hit EC2 directly, or bypass EC2 and hit RDS directly — enforced by AWS at the network layer, not by convention.

**Single-AZ RDS for this project, not Multi-AZ.** A deliberate cost/complexity tradeoff appropriate for a learning/portfolio project on AWS's Free Plan. In a real production deployment for this workload, Multi-AZ would be the correct choice — noted explicitly here rather than silently cutting a corner.

**Remote state (S3, native locking) — added after a real incident.** State initially lived only locally. When GitHub Actions ran without shared state, it had no knowledge of already-existing infrastructure and attempted to recreate it, causing duplicate resources. Root cause fixed by migrating to an S3 backend with native state locking, so local and CI environments always share one source of truth.

**Keyless EC2 access via SSM, not SSH.** No inbound port 22 anywhere in this architecture. EC2 instances are managed through AWS Systems Manager Session Manager, which requires only an IAM role and outbound connectivity — reducing attack surface compared to traditional SSH key management.
**EC2 in public subnets, not private, despite RDS being private.** This is a deliberate cost/architecture tradeoff, not an oversight: private-subnet EC2 instances would require a NAT Gateway (~$32/month, never free-tier eligible) purely to reach the internet for OS package installs. Security for the web tier is instead enforced entirely by the security group (only the ALB's security group may reach port 80) rather than by subnet isolation. RDS has no equivalent outbound need, so it gets the stronger private-subnet guarantee at no extra cost. In a cost-insensitive production environment, moving EC2 to private subnets behind a NAT Gateway (or NAT instance) would be the next hardening step.

## Known Limitations / What I'd Improve at Scale

- RDS would move to Multi-AZ with automated backups retained (currently `skip_final_snapshot = true`, appropriate only for a disposable learning environment)
- The CI/CD IAM user currently uses `PowerUserAccess` plus a scoped inline IAM policy; a tighter, fully custom least-privilege policy would be a further hardening step (planned as part of Project 6 - DevSecOps)
- No WAF or CloudFront in front of the ALB yet — reasonable next addition for a public-facing production app
- HTTPS listener (port 443) is not yet configured, pending an ACM certificate

## Cost Estimate

Built and tested entirely within AWS's Free Plan (credits-based, not the legacy 12-month free tier). Approximate on-demand costs if run beyond free coverage: ALB ~$16-20/month + LCU usage, 2x t3.micro EC2 ~$15/month combined, RDS db.t3.micro Single-AZ ~$12-15/month, S3/DynamoDB state storage negligible (<$1/month).

## Teardown

```bash
cd terraform
terraform destroy
```
Confirms and removes every resource. Verified no orphaned resources remain via AWS Console cross-check after destroy (VPC, EC2, RDS, ALB, IAM, S3 state bucket retained intentionally for state history).
