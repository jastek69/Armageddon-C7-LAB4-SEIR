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

Current backend default is S3 lock files (`use_lockfile = true`).  
To activate DynamoDB locking, add `dynamodb_table = "taaops-terraform-state-lock"` in:
- `Tokyo/backend.tf`
- `global/backend.tf`
- `saopaulo/backend.tf`

After backend changes:

```bash
(cd Tokyo && terraform init -reconfigure)
(cd global && terraform init -reconfigure)
(cd saopaulo && terraform init -reconfigure)
```

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

Run from LAB3 root:

```bash
bash ./terraform_startup.sh
```

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
mysql -h <tokyo-rds-endpoint> -u admin -p taaopsdb
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

## 🔒 **DynamoDB State Locking Deep Dive**

### **Why State Locking Matters**

**The Problem:**
Without state locking, concurrent Terraform operations can corrupt your state file:
```bash
# Terminal 1: Developer A runs
terraform apply  # Takes 3 minutes

# Terminal 2: Developer B runs simultaneously  
terraform apply  # Corruption risk! 💥
```

**The Solution:**
DynamoDB provides atomic locking to ensure only one Terraform operation runs per state file.

### **AWS Documentation References**

- **Official Guide**: [S3 Backend with DynamoDB Locking](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- **DynamoDB**: [AWS DynamoDB Developer Guide](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/)
- **Best Practices**: [Terraform State Management](https://developer.hashicorp.com/terraform/tutorials/state)

### **How State Locking Works**

1. **Lock Acquisition**: Terraform writes a lock record to DynamoDB with operation metadata
2. **Operation Execution**: If lock successful, Terraform proceeds with plan/apply/destroy
3. **Lock Release**: After completion, Terraform removes the lock record  
4. **Conflict Prevention**: Concurrent operations wait or fail gracefully

```bash
# What you see during lock conflicts:
Error: Error locking state: ConditionalCheckFailedException: 
The conditional request failed

Lock Info:
  ID:        1a2b3c4d-e5f6-7890-abcd-ef1234567890
  Path:      your-bucket/tokyo/terraform.tfstate
  Operation: OperationTypeApply
  Who:       john@laptop
  Version:   1.5.7
  Created:   2026-02-07 15:30:00 UTC
```

### **Setting Up DynamoDB Tables Properly**

**Option 1: Use Terraform (Recommended)**
```bash
# Tokyo (from LAB3 root)
(cd Tokyo && terraform init -backend=false && terraform apply -target=aws_dynamodb_table.terraform_lock)

# Sao Paulo (from LAB3 root)
(cd saopaulo && terraform init -backend=false && terraform apply -target=aws_dynamodb_table.terraform_lock)
```

**Option 2: Manual AWS CLI Setup**
```bash
# Tokyo region table
aws dynamodb create-table \
  --table-name taaops-terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-northeast-1 \
  --tags Key=Purpose,Value=TerraformStateLocking

# São Paulo region table
aws dynamodb create-table \
  --table-name taaops-terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region sa-east-1 \
  --tags Key=Purpose,Value=TerraformStateLocking
```

### **Testing State Locking**

Verify your locking works:
```bash
# Terminal 1: Start long-running command
cd Tokyo/
terraform plan -detailed-exitcode

# Terminal 2: Try concurrent operation (should wait)
cd Tokyo/  
terraform plan
# Expected: "Error locking state: ConditionalCheckFailedException"
```

### **Managing Locks in Production**

**Check Active Locks:**
```bash
# View current locks
aws dynamodb scan \
  --table-name taaops-terraform-state-lock \
  --region ap-northeast-1

# Check specific state file lock
aws dynamodb get-item \
  --table-name taaops-terraform-state-lock \
  --key '{"LockID":{"S":"your-bucket/tokyo/terraform.tfstate-md5"}}' \
  --region ap-northeast-1
```

**Emergency Lock Removal:**
```bash
# When someone's laptop crashes during apply
terraform force-unlock <LOCK_ID>

# Example:
terraform force-unlock 1a2b3c4d-e5f6-7890-abcd-ef1234567890
```

### **Cost Analysis: DynamoDB State Locking**

**Pricing (Pay-per-Request Model):**
- Write requests: $0.25 per million writes
- Read requests: $0.05 per million reads
- Storage: $0.25 per GB-month

**Real-world Cost Example (5-person team):**
```
Operations per month: ~200 lock/unlock cycles
DynamoDB writes: 400 
DynamoDB reads: 400
Monthly cost: ~$0.10 (less than 10 cents!)

Annual cost for state locking: ~$1.20 per project
```

**Free Tier Coverage:**
- 25 WCU/RCU per month (sufficient for small teams)
- First year covers most small to medium teams

### **Required IAM Permissions**

Add these permissions to your Terraform execution role:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": [
        "arn:aws:dynamodb:ap-northeast-1:*:table/taaops-terraform-state-lock",
        "arn:aws:dynamodb:sa-east-1:*:table/taaops-terraform-state-lock"
      ]
    }
  ]
}
```

### **Troubleshooting State Locking Issues**

| Issue | Cause | Solution |
|-------|-------|----------|
| `ResourceNotFoundException` | DynamoDB table doesn't exist | Create table in correct region |
| `AccessDenied` | Missing DynamoDB permissions | Add IAM permissions above |
| Stale locks after crash | Process terminated unexpectedly | Use `terraform force-unlock` |
| Lock timeout | Another operation running | Wait or coordinate with team |

**Debug Commands:**
```bash
# Check if table exists
aws dynamodb describe-table \
  --table-name taaops-terraform-state-lock \
  --region ap-northeast-1

# View table contents
aws dynamodb scan \
  --table-name taaops-terraform-state-lock \
  --region ap-northeast-1 \
  --max-items 5

# Check Terraform state metadata
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
