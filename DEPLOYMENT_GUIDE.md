# Multi-Region Terraform Architecture - Tokyo & São Paulo

## 📁 Repository Structure

```
lab-3/
├── Tokyo/                    # 🏯 Tokyo Region (Primary - Data Authority)
│   ├── main.tf              # Complete Lab 2 + TGW hub
│   ├── outputs.tf            # Exposes TGW ID, VPC CIDR, RDS endpoint
│   ├── variables.tf          # Tokyo-specific variables
│   └── backend.tf            # Remote state configuration
│
├── global/                   # 🌐 Global Edge Stack (CloudFront/Route53)
│   ├── main.tf
│   ├── outputs.tf
│   ├── data.tf
│   └── backend.tf
│
├── saopaulo/                 # 🌴 São Paulo Region (Compute Spoke)
│   ├── main.tf              # Lab 2 minus DB + TGW spoke  
│   ├── variables.tf          # São Paulo-specific variables
│   ├── data.tf               # Reads Tokyo remote state
│   └── backend.tf            # Remote state configuration
│
├── terraform_startup.sh      # Apply wrapper (Tokyo -> global -> saopaulo)
├── terraform_destroy.sh      # Destroy wrapper (global -> newyork_gcp -> saopaulo -> Tokyo)
└── DEPLOYMENT_GUIDE.md       # This file
```

## 🚀 **Deployment Sequence (IMPORTANT!)**

### **Step 1: Setup Remote State Backends**
Before deploying, ensure backend buckets exist (one per regional stack in this repo):

```bash
# Tokyo state bucket
aws s3 mb s3://taaops-terraform-state-tokyo --region ap-northeast-1

# Sao Paulo state bucket
aws s3 mb s3://taaops-terraform-state-saopaulo --region sa-east-1
```

Optional (team/CI): enable DynamoDB locking in addition to S3 lock files.

```bash
# Tokyo-region lock table
aws dynamodb create-table \
  --table-name taaops-terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-northeast-1

# Sao Paulo-region lock table
aws dynamodb create-table \
  --table-name taaops-terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region sa-east-1
```

### **Step 2: Configure Backend Settings**

DynamoDB state locking is **already enabled** in all four stacks via `dynamodb_table = "taaops-terraform-state-lock"`. The tables exist in both `ap-northeast-1` and `sa-east-1` with `PAY_PER_REQUEST` billing.

Affected backends (all already configured):
- `Tokyo/backend.tf`
- `global/backend.tf`
- `saopaulo/backend.tf`
- `newyork_gcp/2-backend.tf`

If you ever change a backend key or switch regions, re-initialize with:

```bash
(cd Tokyo && terraform init -reconfigure)
(cd global && terraform init -reconfigure)
(cd saopaulo && terraform init -reconfigure)
(cd newyork_gcp && terraform init -reconfigure)
```

### **Step 2b: Load Secrets Before Any Terraform Command**

> **Why a `.secrets.env` file?**  
> VPN Pre-Shared Keys (PSKs) and the Aurora DB password are sensitive credentials that must never be stored in `terraform.tfvars` or committed to version control. Instead, they live in `.secrets.env` at the repo root — excluded from Git via `.gitignore` — and are injected into Terraform as `TF_VAR_*` environment variables at runtime.

**First time (or after a fresh clone):** copy the example template and fill in your values:
```bash
cp .secrets.env.example .secrets.env
# Then edit .secrets.env — the db_password line fetches automatically from Secrets Manager;
# do not replace it unless you want to use a static value.
```

**Every deploy/destroy session:** source the file to load all secrets into your shell:
```bash
source .secrets.env
```

This sets:
| Variable | Source |
|---|---|
| `TF_VAR_db_password` | Fetched live from `taaops/rds/mysql` in Secrets Manager (`ap-northeast-1`) |
| `TF_VAR_psk_tunnel_1..4` | VPN PSKs for TGW VPN resources |
| `TF_VAR_aws_gcp_psk_tunnel_1..4` | VPN PSKs for AWS↔GCP HA VPN connections |

`terraform_startup.sh` validates that all required variables are set before proceeding and exits with a clear error message if any are missing.

Remote State Key Checklist (update these together for new deployments)
| Stack / Reference | File and line range | Setting |
| --- | --- | --- |
| Tokyo backend key | [Tokyo/backend.tf](Tokyo/backend.tf#L6-L12) | `key` |
| Global backend key | [global/backend.tf](global/backend.tf#L3-L9) | `key` |
| Sao Paulo backend key | [saopaulo/backend.tf](saopaulo/backend.tf#L6-L12) | `key` |
| New York GCP backend key | [newyork_gcp/2-backend.tf](newyork_gcp/2-backend.tf#L2-L8) | `key` |
| Global -> Tokyo remote state | [global/terraform.tfvars](global/terraform.tfvars#L6-L8) | `tokyo_state_key` |
| Sao Paulo -> Tokyo remote state | [saopaulo/terraform.tfvars](saopaulo/terraform.tfvars#L3-L5) | `tokyo_state_key` |
| New York GCP -> Tokyo remote state | [newyork_gcp/terraform.tfvars](newyork_gcp/terraform.tfvars#L22-L24) | `tokyo_state_key` |
| Tokyo -> GCP remote state | [Tokyo/terraform.tfvars](Tokyo/terraform.tfvars#L63-L66) | `gcp_state_key` |
| Tokyo -> Sao Paulo remote state | [Tokyo/main.tf](Tokyo/main.tf#L46-L55) | `key` |

### **Step 3: Deploy with Wrapper Script (Recommended)**
Run from `<project>` root:


Load secrets and run the startup script:
```bash
# From LAB4 root
source .secrets.env          # loads PSKs + fetches db_password from Secrets Manager
bash ./terraform_startup.sh  # GCP seed -> Tokyo -> global -> newyork_gcp -> saopaulo
```

`terraform_startup.sh` will abort immediately if any required `TF_VAR_*` is unset.

**Full destroy + redeploy cycle:**
```bash
source .secrets.env
bash terraform_destroy.sh    # type DESTROY when prompted; order: global -> newyork_gcp -> saopaulo -> Tokyo
source .secrets.env          # re-source after destroy (shell may have been closed)
bash terraform_startup.sh    # fully automated after secrets are sourced


Windows Line Endings Fix (if scripts fail with /usr/bin/env)
```bash
sed -i 's/\r$//' terraform_startup.sh terraform_apply.sh
```

Notes:
- This repo's apply wrapper is `terraform_startup.sh` (same role as `terraform_apply.sh`).
- Deployment order is `Tokyo -> global -> saopaulo`.
- `force_destroy` in [Tokyo/terraform.tfvars](Tokyo/terraform.tfvars) is currently `true` to allow S3 cleanup during destroy; set to `false` for production.

### **Step 4: Manual Deployment (Alternative)**

```bash
(cd Tokyo && terraform init -upgrade && terraform plan && terraform apply)
(cd global && terraform init -upgrade && terraform plan && terraform apply)
(cd saopaulo && terraform init -upgrade && terraform plan && terraform apply)
```

### **Step 5: Destroy Workflow**

Recommended:

```bash
bash ./terraform_destroy.sh
```

Script destroy order is remote-state-safe:
1. `global`
2. `newyork_gcp`
3. `saopaulo`
4. `Tokyo`

Manual alternative:

```bash
(cd global && terraform destroy)
(cd Tokyo && terraform destroy)
(cd saopaulo && terraform destroy)
```

## ✅ **Reset Checklist (clean apply/destroy)**

- Confirm what must be retained (Route53 public zone, ACM certs) before any destroy.
- Verify backend keys and remote state keys match the current deployment in the Remote State Key Checklist above; run `terraform init -reconfigure` in each stack after changes.
- For a full destroy, set `enable_aws_gcp_tgw_vpn = false` in [newyork_gcp/terraform.tfvars](newyork_gcp/terraform.tfvars) if Tokyo state is missing, and set VPN lifecycle `prevent_destroy = false` in [newyork_gcp/5-gcp-vpn-connections.tf](newyork_gcp/5-gcp-vpn-connections.tf) during teardown.
- If you need S3 buckets to delete cleanly, keep `force_destroy = true` in [Tokyo/terraform.tfvars](Tokyo/terraform.tfvars) during destroy, then restore to `false` after.
- Run `./terraform_destroy.sh` from repo root and confirm all four stacks complete; if any stack fails due to missing state, remove remaining resources manually before a clean apply.
- For a clean apply from empty state, run `./terraform_startup.sh` from repo root (GCP seed -> Tokyo -> global -> newyork_gcp -> saopaulo).
- **Secrets Manager pending deletion:** After a destroy, `taaops/rds/mysql` enters a recovery window and blocks recreation. `terraform_startup.sh` automatically force-deletes any pending secrets in Stage -3. If running manually, clear them first: `aws secretsmanager delete-secret --secret-id "taaops/rds/mysql" --force-delete-without-recovery --region ap-northeast-1`
- **Lab vs Production — `recovery_window_in_days`:** `Tokyo/database.tf` sets `recovery_window_in_days = 0` for fast lab redeploys. In a production pipeline, change this to `7` or `30` to protect against accidental credential loss. With a non-zero value, the Stage -3 pre-flight in `terraform_startup.sh` handles the force-delete automatically during redeploys.

## ✅ **Partial Reset Scenarios**

- **Global only (CloudFront/WAF/Route53):** keep Tokyo and Sao Paulo intact; run `(cd global && terraform destroy)` and re-apply when ready. Make sure `tokyo_state_key` in [global/terraform.tfvars](global/terraform.tfvars) still points at the active Tokyo state.
- **Sao Paulo only (compute spoke):** keep Tokyo intact; destroy and re-apply only Sao Paulo. Validate [saopaulo/terraform.tfvars](saopaulo/terraform.tfvars) `tokyo_state_key` and TGW peering outputs before apply.
- **Tokyo only (data authority):** avoid if Sao Paulo or global still depend on Tokyo outputs; if required, destroy Sao Paulo and global first, then Tokyo, then rebuild Tokyo before re-applying dependents.
- **New York GCP only:** keep AWS stacks intact; run `(cd newyork_gcp && terraform destroy)` and re-apply. If Tokyo state is missing, set `enable_aws_gcp_tgw_vpn = false` in [newyork_gcp/terraform.tfvars](newyork_gcp/terraform.tfvars) to skip VPN resources.
- **Remote state refresh only:** change keys or buckets, then run `terraform init -reconfigure` in each affected stack without destroy/apply.

## 🔗 **Inter-Region Dependencies**

### **Tokyo Exposes:**
- `tokyo_transit_gateway_id` → Used by São Paulo for TGW peering
- `tokyo_vpc_cidr` → Used for São Paulo routing tables  
- `rds_endpoint` → Database connection for São Paulo apps
- `db_secret_arn` → Database credentials access

### **São Paulo Consumes:**
- Reads Tokyo remote state via `data.tf`
- Creates TGW peering connection to Tokyo
- Routes database traffic through TGW
- Configures security groups for cross-region access

## 🔌 **VPC Endpoints**

- **Tokyo:** Interface endpoints for SSM, EC2 Messages, SSM Messages, and CloudWatch Logs; S3 uses a gateway endpoint on the private route table.
- **Sao Paulo:** Same interface endpoints plus an S3 gateway endpoint on the private route table.
- Endpoint IDs and DNS names are exposed in Tokyo and Sao Paulo outputs.

## 🧪 **Origin Debug Note**

- The Tokyo ALB security group allows only the CloudFront origin-facing prefix list. Direct curls to the ALB from your laptop will fail.
- If you see 500s during init, verify CloudFront can reach `origin.jastek.click`, then check Tokyo instance logs via SSM.

### **Origin Debug Commands**
```bash
# CloudFront response headers
curl -I https://jastek.click
curl -I https://app.jastek.click

# CloudFront origin domain
aws cloudfront get-distribution --id <DISTRIBUTION_ID> \
  --query "Distribution.DistributionConfig.Origins.Items[0].DomainName" --output text

# Route53 origin record
aws route53 list-hosted-zones-by-name --dns-name jastek.click --query "HostedZones[0].Id" --output text
aws route53 list-resource-record-sets --hosted-zone-id <ZONE_ID> \
  --query "ResourceRecordSets[?Name=='origin.jastek.click.']" --output json

# Tokyo instance app check via SSM
aws ssm send-command --region ap-northeast-1 \
  --document-name "AWS-RunShellScript" \
  --instance-ids <TOKYO_INSTANCE_IDS> \
  --parameters 'commands=["curl -I http://localhost","curl -I http://localhost:5000","sudo tail -n 60 /var/log/cloud-init-output.log"]'

# Tokyo ALB SG (CloudFront prefix list)
aws ec2 describe-managed-prefix-lists --region ap-northeast-1 \
  --query "PrefixLists[?PrefixListName=='com.amazonaws.global.cloudfront.origin-facing'].[PrefixListId,PrefixListName]" --output table
```

## 🛡️ **Security Architecture**

### **Database Security:**
- ✅ **Database only in Tokyo** (data sovereignty)
- ✅ **São Paulo access via TGW** (encrypted transit)
- ✅ **No public database access**
- ✅ **Secrets Manager integration**

### **Network Security:**
- ✅ **Inter-region encryption** (TGW default)
- ✅ **Security group rules** for cross-region traffic
- ✅ **VPC isolation** with controlled routing

## 📊 **Resource Distribution**

| Component | Tokyo | São Paulo |
|-----------|-------|-----------|
| **VPC** | ✅ `shinjuku_vpc01` | ✅ `liberdade_vpc01` |
| **Database** | ✅ Aurora MySQL | ❌ None (uses Tokyo) |
| **Compute** | ✅ EC2/ASG | ✅ EC2/ASG |
| **Load Balancer** | ✅ ALB + CloudFront | ✅ Local ALB |
| **Transit Gateway** | ✅ Hub | ✅ Spoke |
| **IAM Roles** | ✅ Full Lab 2 roles | ✅ Compute-only roles |
| **KMS/Secrets** | ✅ Shared services | ❌ References Tokyo |

## 🔧 **Management Commands**

### **⚠️ Windows / Git Bash Gotchas**

**MSYS POSIX path auto-conversion:**
Git Bash (MSYS2) automatically converts POSIX-style `/` paths to Windows paths before passing them to native
Windows binaries (e.g. `aws.exe`, `terraform.exe`). This silently corrupts CloudFront invalidation paths,
S3 keys, and any argument starting with `/`.

Symptom: `InvalidArgument: Your request contains one or more invalid invalidation paths`
Cause: `/static/placeholder.png` → `C:/Program Files/Git/static/placeholder.png`

**Fix — set these at the top of any script that passes `/`-prefixed values to AWS CLI:**
```bash
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL="*"
```
Or inline for one-off commands:
```bash
MSYS_NO_PATHCONV=1 aws cloudfront create-invalidation --distribution-id EXXXXX --paths "/static/*"
```

**Python path on this machine:** `/c/Python311/python.exe` (not `python3` — not in PATH)

**Terraform binary:** `~/bin/terraform.exe` (1.14.6 stable, added to PATH via `.secrets.env`)
The Chocolatey-installed version at `C:\ProgramData\chocolatey\bin\terraform.exe` is a stale alpha build.

### **Show TGW Peering Status:**
```bash
# From Tokyo
terraform output tokyo_transit_gateway_id

# From São Paulo - verify peering
aws ec2 describe-transit-gateway-peering-attachments \
    --region sa-east-1 \
    --filters "Name=state,Values=available"
```

### **Test Database Connectivity:**
```bash
# From São Paulo EC2 instance
mysql -h <tokyo-rds-endpoint> -u admin -p galactus
```

### **Destroy Infrastructure:**
```bash
# Preferred: use wrapper from LAB3 root
bash ./terraform_destroy.sh

# Manual fallback (same order as script)
(cd global && terraform destroy)
(cd newyork_gcp && terraform destroy)
(cd saopaulo && terraform destroy)
(cd Tokyo && terraform destroy)
```

# Check Terraform state metadata
```bash
terraform show -json | jq '.version, .serial'
```

### **State Locking Best Practices**

**For Teams:**
1. **Always enable locking** in shared environments
2. **Use lock timeouts** in CI/CD: `terraform plan -lock-timeout=5m`
3. **Communicate long operations** in team chat
4. **Monitor stale locks** - investigate locks older than 30 minutes

**For CI/CD Pipelines:**
```bash
# In your deployment scripts
terraform init -input=false
terraform plan -lock-timeout=10m -input=false -out=plan.tfplan
terraform apply -lock-timeout=10m -input=false plan.tfplan
```

**Backup and Recovery:**
```bash
# Enable point-in-time recovery on DynamoDB table
aws dynamodb update-continuous-backups \
  --table-name taaops-terraform-state-lock \
  --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true \
  --region ap-northeast-1
```

## ⚠️ **Important Notes**

1. **Deploy Order:** Tokyo MUST be deployed before São Paulo
2. **State Dependencies:** São Paulo reads Tokyo's remote state
3. **State Locking:** Enable DynamoDB locking for team environments (see detailed section above)
4. **TGW Timing:** Allow 2-3 minutes for TGW peering to establish
5. **Cost Management:** Consider TGW data transfer costs between regions
6. **Security:** Database access is only via TGW - no public endpoints
7. **Lock Management:** Monitor and cleanup stale locks in production environments

---

## 🧹 Manual Cleanup (Pre-Redeploy)

When `terraform_destroy.sh` cannot run (connectivity failure, orphaned resources from previous deploys), manually verify the following before running `terraform_startup.sh`.

### Verification Scripts

```bash
chmod +x cleanup_verify.sh cleanup_verify_gcp.sh

# AWS — Tokyo (ap-northeast-1) + Sao Paulo (sa-east-1)
./cleanup_verify.sh

# GCP — newyork_gcp (project: taaops, region: us-central1)
./cleanup_verify_gcp.sh
```

Both exit `1` (DIRTY) if blocking resources remain, `0` if safe to redeploy.

### AWS — Tokyo (ap-northeast-1)

#### 🔴 Must Verify Clean

| Resource | Console Location | What to Look For |
|---|---|---|
| **Transit Gateways** | VPC → Transit Gateways | Delete extras — only 1 expected. Orphaned TGWs cause VPN connections to attach to the wrong gateway |
| **VPCs** | VPC → Your VPCs | Delete all `nihonmachi` / lab VPCs — duplicates cause TGW attachment conflicts |
| **VPN Connections** | VPC → Site-to-Site VPN | Delete all — orphaned ones show `AttachID: None` |
| **Customer Gateways** | VPC → Customer Gateways | Delete `gcp_cgw_1` and `gcp_cgw_2` — persist after VPN deletion |
| **Aurora RDS Cluster** | RDS → Databases | Delete cluster + instances — cannot be deployed over |
| **NAT Gateways** | VPC → NAT Gateways | Delete — ~$32/mo each if left running |
| **Elastic IPs** | EC2 → Elastic IPs | Release unassociated EIPs left after NAT gateway deletion |
| **Route53 Private Zones** | Route53 → Hosted Zones | Delete `nihonmachi` zone — Terraform will conflict on create |

#### 🟡 Check But Less Likely to Block

| Resource | Notes |
|---|---|
| **IAM Roles/Policies** | Name conflicts cause `apply` errors — delete any with `taaops` / `tokyo` prefix |
| **Lambda Functions** | Delete `tokyo_ir_lambda` and `tokyo_secrets_rotation` if present |
| **S3 Buckets** (non-backend) | `taaops-regional-waf-*`, `tokyo-backend-logs-*`, `tokyo-ir-reports-*` — empty and delete |
| **ALB** | Delete load balancer + target groups |
| **Kinesis Firehose** | Delete `taaops-regional-waf-firehose` if present |
| **KMS Keys** | 7-day minimum deletion delay — leave them, Terraform creates new ones |


#### 🟢 Safe to Leave Alone
- `taaops-terraform-state-tokyo` S3 bucket — keep the bucket, only delete the `.tfstate` objects inside it
- Security Groups — deleted automatically when their VPC is deleted

#### Quick CLI Scan

```bash
# VPCs
aws ec2 describe-vpcs --region ap-northeast-1 \
  --query "Vpcs[?!IsDefault].{ID:VpcId,CIDR:CidrBlock,Name:Tags[?Key=='Name']|[0].Value}" \
  --output table

# Transit Gateways
aws ec2 describe-transit-gateways --region ap-northeast-1 \
  --query "TransitGateways[*].{ID:TransitGatewayId,State:State,Name:Tags[?Key=='Name']|[0].Value}" \
  --output table

# Orphaned VPN connections
aws ec2 describe-vpn-connections --region ap-northeast-1 \
  --query "VpnConnections[?State!='deleted'].{ID:VpnConnectionId,State:State,TGW:TransitGatewayId,AttachID:TransitGatewayAttachmentId}" \
  --output table

# NAT Gateways
aws ec2 describe-nat-gateways --region ap-northeast-1 \
  --query "NatGateways[?State!='deleted'].{ID:NatGatewayId,State:State,VPC:VpcId}" \
  --output table
```

### GCP — newyork_gcp (us-central1)

#### 🔴 Must Verify Clean

| Resource | gcloud Command |
|---|---|
| VPC + Subnets | `gcloud compute networks list --filter="name:nihonmachi" --project=taaops` |
| MIG | `gcloud compute instance-groups managed list --regions=us-central1 --filter="name:nihonmachi" --project=taaops` |
| Instance Templates | `gcloud compute instance-templates list --filter="name:nihonmachi" --project=taaops` |
| VPN Tunnels (tunnel00-03) | `gcloud compute vpn-tunnels list --regions=us-central1 --filter="name:tunnel0" --project=taaops` |
| HA VPN Gateways | `gcloud compute vpn-gateways list --regions=us-central1 --filter="name:gcp-to-aws" --project=taaops` |
| External VPN Gateways | `gcloud compute external-vpn-gateways list --filter="name:gcp-to-aws" --project=taaops` |
| Cloud Routers | `gcloud compute routers list --regions=us-central1 --filter="name:nihonmachi OR name:gcp-to-aws" --project=taaops` |
| ILB (Forwarding Rules, Backend Services, Health Checks) | `gcloud compute forwarding-rules list --regions=us-central1 --filter="name:nihonmachi" --project=taaops` |

#### 🟡 Check But Less Likely to Block

| Resource | Notes |
|---|---|
| Firewall Rules | Auto-deleted with VPC, but orphaned if VPC was already manually deleted |
| Secret Manager (`nihonmachi-*`) | Terraform errors on create if secret name already exists |

---

## 🎯 **Benefits of This Architecture**

- ✅ **Separated concerns** - Database vs Compute regions
- ✅ **Independent state management** - No monolithic state files  
- ✅ **Production-ready state locking** - DynamoDB prevents concurrent conflicts
- ✅ **Secure cross-region connectivity** - TGW encrypted transit
- ✅ **Data sovereignty** - Database remains in Tokyo
- ✅ **Scalable compute** - EC2 auto-scaling in São Paulo
- ✅ **Clean dependencies** - Clear resource ownership
- ✅ **Team-friendly** - State locking enables safe collaboration

---

🚀 **Your multi-region infrastructure is ready for deployment!**
