# LAB4 Deployment Scripts

## 🚀 Quick Start

Run these from the root directory: e.g. `LAB4` repository root (`SEIR_Foundations/LAB4`).

Note on naming:
- This repo's apply wrapper is `terraform_startup.sh`.
- If you renamed/copied it to `terraform_apply.sh`, run it the same way.

### Deploy Everything
```bash
bash ./terraform_startup.sh
# or (if you created it)
bash ./terraform_apply.sh
```

> **Before running either script**, you must export secret environment variables.
> See the [Environment Secrets](#-environment-secrets) section below.

```bash
# Step 1 — load secrets into the current shell session
source .secrets.env

# Step 2 — deploy all stacks
bash ./terraform_startup.sh
```

Windows Line Endings Fix (if scripts fail with `\r` or `/usr/bin/env` errors)
```bash
sed -i 's/\r$//' terraform_startup.sh terraform_destroy.sh
```

### Destroy Everything
```bash
source .secrets.env   # PSK vars are required even for destroy
bash ./terraform_destroy.sh
```


## 📋 Script Overview

### `terraform_startup.sh`
**Deploys the complete LAB4 multi-region architecture in dependency order:**

1. **🌱 GCP Seed** - GCP service account + IAM bootstrap (targeted apply)
2. **🏯 Tokyo Region** - Primary hub: Aurora RDS, VPC, TGW hub, ALB, SSM endpoints
3. **🌐 Global Stack** - CloudFront CDN, Route53, WAF, global edge controls
4. **🗽 New York GCP** - GCP stateless compute, HA VPN tunnels, BGP to TGW
5. **🌴 São Paulo Region** - Compute spoke: VPC, TGW spoke, ALB
6. **🔍 Summary Outputs** - Captures JSON outputs to `LAB4-DELIVERABLES/`

**Features:**
- ✅ Proper deployment sequencing (GCP seed → Tokyo → Global → New York GCP → São Paulo)
- ✅ Transit Gateway peering wait times (120s)
- ✅ Pre-flight check: validates all required `TF_VAR_*` secrets are set
- ✅ Tokyo state guard: dependent stacks are skipped if Tokyo apply failed
- ✅ Comprehensive output collection
- ✅ Error handling with line number reporting

### `terraform_destroy.sh`
**Safely destroys infrastructure in a remote-state-safe order:**

1. **🌐 Global** - Removes CloudFront/Route53 dependencies first
2. **🗽 New York GCP** - Depends on Tokyo remote state — destroyed before Tokyo
3. **🌴 São Paulo** - Depends on Tokyo remote state — destroyed before Tokyo
4. **🏯 Tokyo** - Hub destroyed last (source of truth for other stacks)
5. **🧹 Cleanup** - Removes `.tfplan` files

**Safety Features:**
- ✅ Confirmation prompts before destruction
- ✅ 10-second countdown with Ctrl+C abort
- ✅ Proper dependency order (global → newyork_gcp → saopaulo → Tokyo)
- ✅ Resource verification after destruction
- ✅ S3 state bucket preservation (with manual cleanup instructions)

## 🎯 Usage Examples

### Standard Deployment
```bash
# Deploy complete LAB4 infrastructure
source .secrets.env
bash ./terraform_startup.sh

# Expected output sequence:
# Starting LAB4 deployment: GCP seed -> Tokyo -> Global -> New York GCP -> Sao Paulo
# === Deploying Tokyo ===
# === Deploying global ===
# === Deploying newyork_gcp ===
# === Deploying saopaulo ===
# LAB4 deployment complete.
```

### Cleanup Deployment
```bash
# Destroy all infrastructure
source .secrets.env
bash ./terraform_destroy.sh

# Prompts:
# - Type 'DESTROY' to confirm
# - 10-second countdown
```

NOTE: You will need to manually destroy the S3 backend bucket.


Short version if versioning is off or not concerned about the versions:
```bash
aws s3 rb s3://taaops-terraform-state-saopaulo --force --region sa-east-1
```

If versioning is enabled - to delete all versions and delete markers before the bucked can be removed:
```bash
# 1. Delete all object versions
aws s3api delete-objects \
  --bucket taaops-terraform-state-saopaulo \
  --region sa-east-1 \
  --delete "$(aws s3api list-object-versions \
    --bucket taaops-terraform-state-saopaulo \
    --region sa-east-1 \
    --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
    --output json)" 2>/dev/null

# 2. Delete all delete markers
aws s3api delete-objects \
  --bucket taaops-terraform-state-saopaulo \
  --region sa-east-1 \
  --delete "$(aws s3api list-object-versions \
    --bucket taaops-terraform-state-saopaulo \
    --region sa-east-1 \
    --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' \
    --output json)" 2>/dev/null

# 3. Force-empty any remaining objects and delete the bucket - --force empties current objects but won't remove old versions — use the three-step version above to be thorough.
aws s3 rb s3://taaops-terraform-state-saopaulo --force --region sa-east-1
```

### Manual Steps (if needed)
```bash
# Individual stack deployment
(cd Tokyo && terraform init && terraform apply)
(cd global && terraform init && terraform apply)
(cd saopaulo && terraform init && terraform apply)

# Individual stack destruction (match script order)
(cd global && terraform destroy)
(cd Tokyo && terraform destroy)
(cd saopaulo && terraform destroy)
```

## 🔧 Prerequisites

Before running the scripts:

1. **AWS CLI configured** with appropriate permissions
2. **GCP service account key** (`newyork_gcp/taaops-*.json`) present on disk
3. **Update backend.tf files** with your actual S3 bucket names:
   ```hcl
   bucket = "your-actual-bucket-name-tokyo"
   ```
4. **Create S3 buckets** for state storage (scripts do not create state buckets)
5. **State locking** is handled by `use_lockfile = true` (Terraform 1.10+ S3 native locking — no DynamoDB required)
6. **Terraform >= 1.10** installed
7. **Environment secrets loaded** — see section below

## 🔐 Environment Secrets

The startup script **will not run** until all required `TF_VAR_*` variables are set in the shell. They are never stored in `terraform.tfvars` or `.tf` files.

### Setup

```bash
# Copy the template (one-time)
cp .secrets.env.example .secrets.env

# Edit with real values
nano .secrets.env    # or any text editor

# Load into your shell before every deployment session
source .secrets.env
```

`.secrets.env` is listed in `.gitignore` — it will never be committed. The `.secrets.env.example` template is safe to commit.

### Required Variables

| Variable | Used By | Description |
|----------|---------|-------------|
| `TF_VAR_db_password` | Tokyo | Aurora MySQL master password |
| `TF_VAR_psk_tunnel_1` | newyork_gcp | HA VPN PSK — AWS VPN1 / Tunnel 1 |
| `TF_VAR_psk_tunnel_2` | newyork_gcp | HA VPN PSK — AWS VPN1 / Tunnel 2 |
| `TF_VAR_psk_tunnel_3` | newyork_gcp | HA VPN PSK — AWS VPN2 / Tunnel 1 |
| `TF_VAR_psk_tunnel_4` | newyork_gcp | HA VPN PSK — AWS VPN2 / Tunnel 2 |

> `TF_VAR_aws_gcp_psk_tunnel_1` through `TF_VAR_aws_gcp_psk_tunnel_4` are also set in the example file; they mirror the `TF_VAR_psk_tunnel_*` values for the GCP-side provider.

### Generating PSKs

```bash
# Generate a cryptographically secure PSK (do this 4 times, one per tunnel)
openssl rand -base64 48
```

Use a different PSK for each tunnel. Store them in your team's secrets manager (e.g. AWS Secrets Manager) after initial deployment.

### Verifying Secrets Are Loaded

```bash
# Quick check — all 5 required vars must be non-empty
echo "db_password set: ${TF_VAR_db_password:+YES}"
echo "psk_tunnel_1 set: ${TF_VAR_psk_tunnel_1:+YES}"
echo "psk_tunnel_2 set: ${TF_VAR_psk_tunnel_2:+YES}"
echo "psk_tunnel_3 set: ${TF_VAR_psk_tunnel_3:+YES}"
echo "psk_tunnel_4 set: ${TF_VAR_psk_tunnel_4:+YES}"
```

If any show blank instead of `YES`, re-run `source .secrets.env`.
## 📊 Script Output Guide

### Successful Deployment Shows:
```
=== Deploying Tokyo ===
=== Deploying global ===
=== Deploying newyork_gcp ===
=== Deploying saopaulo ===
=== Capturing Terraform outputs for Tokyo ===
=== Capturing Terraform outputs for global ===
=== Capturing Terraform outputs for newyork_gcp ===
=== Capturing Terraform outputs for saopaulo ===
LAB4 deployment complete.
```

### Common Issues and Solutions:

| Issue | Cause | Solution |
|-------|-------|----------|
| `backend not configured` | S3 bucket doesn't exist | Create bucket or update backend.tf |
| `Error acquiring the state lock` | Stale/concurrent lock | Wait for other session or `terraform force-unlock <LOCK_ID>` |
| `ERROR: Required environment variables are not set` | `.secrets.env` not sourced | `source .secrets.env` from LAB4 root |
| `TGW peering failed` | Tokyo not deployed first | Deploy Tokyo before São Paulo |
| `ALB not responding` | Resources still initializing | Wait 5-10 minutes and retry |
| `ERROR: Tokyo state not found` | Tokyo apply failed | Fix Tokyo stack errors, rerun startup script |
| `terraform_destroy.sh: command not found` | Script executed without `./` or from wrong folder | `cd` to `LAB4` root and run `bash ./terraform_destroy.sh` |
| Tunnel shows DOWN after newyork_gcp apply | Normal — IKE negotiation takes ~2 min | Wait 2 minutes and recheck in AWS/GCP console |

## ⚡ Advanced Usage

### Customization Options

**Modify wait times in terraform_startup.sh:**
```bash
WAIT_TIME=30          # General resource wait
TGW_WAIT_TIME=120     # Transit Gateway peering wait
```

**Add custom verification:**
```bash
# Add to verification stage
echo "🧪 Custom health check..."
# Your custom tests here
```

**Selective deployment:**
```bash
# Deploy only Tokyo
cd Tokyo/ && terraform init && terraform apply

# Deploy only New York GCP (requires Tokyo state + secrets loaded)
source .secrets.env
cd newyork_gcp/ && terraform init && terraform apply

# Deploy only São Paulo (requires Tokyo state)
source .secrets.env
cd saopaulo/ && terraform init && terraform apply
```

## 🎯 Integration with CI/CD

### GitHub Actions Example
```yaml
- name: Deploy LAB4
  run: |
    chmod +x terraform_startup.sh
    ./terraform_startup.sh
    
- name: Cleanup on failure
  if: failure()
  run: bash ./terraform_destroy.sh
```

### Pipeline Stages
1. **Secrets Check** - Verify all `TF_VAR_*` vars are loaded
2. **Validate** - `terraform validate` in all 4 stacks
3. **Plan** - `terraform plan` with output files
4. **Deploy** - Sequential multi-stack deployment
5. **Test** - ALB health checks, BGP tunnel status, ILB reachability
6. **Monitor** - Infrastructure status dashboard

---

### Translation of logs from English to Japanese

Run this command in order to trigger the conversion:
```py
/c/Python311/python.exe python/translate_batch_audit.py \
  --input-bucket  taaops-translate-input  \
  --output-bucket taaops-translate-output \
  --source-dir    LAB4-DELIVERABLES       \
  --glob          "*.json"                \
  --key-prefix    lab4-deliverables       \ 
  --region        ap-northeast-1
```



## 🏁 Success Criteria

After successful deployment, you should have:
- ✅ Multi-region VPCs with non-overlapping CIDRs
- ✅ Transit Gateway inter-region peering
- ✅ Aurora MySQL database in Tokyo only
- ✅ Auto-scaling web applications in both regions
- ✅ Load balancers with health checks
- ✅ Regional modules for IAM, S3, and monitoring
- ✅ GCP nihonmachi-mig01 compute connected via HA VPN BGP
- ✅ 4 × BGP tunnels UP between AWS TGW and GCP Cloud Router
- ✅ State locking via `use_lockfile = true` (no DynamoDB required)
- ✅ Outputs captured to `LAB4-DELIVERABLES/` (JSON per stack)

**Total deployment time**: Usually 12-18 minutes for all 4 stacks (newyork_gcp tunnel negotiation adds ~2–3 min).
