# LAB4 Deliverables Checklist

## Output files -built into terrafrom_startup.sh
```bash
(cd Tokyo && terraform output -json > ../LAB4-DELIVERABLES/tokyo-outputs.json)
(cd global && terraform output -json > ../LAB4-DELIVERABLES/global-outputs.json)
(cd newyork_gcp && terraform output -json > ../LAB4-DELIVERABLES/newyork-gcp-outputs.json)
(cd saopaulo && terraform output -json > ../LAB4-DELIVERABLES/saopaulo-outputs.json)
```

# List VPN connections and tunnel status
```bash
aws ec2 describe-vpn-connections --region ap-northeast-1 --query "VpnConnections[*].{Id:VpnConnectionId,State:State,Tunnels:VgwTelemetry}"
```
```bash
[
    {
        "Id": "vpn-0e477dca4384bf6c3",
        "State": "available",
        "Tunnels": [
            {
                "AcceptedRouteCount": 2,
                "LastStatusChange": "2026-03-07T23:01:00+00:00",
                "OutsideIpAddress": "35.72.94.63",
                "Status": "UP",
                "StatusMessage": "2 BGP ROUTES"
            },
            {
                "AcceptedRouteCount": 2,
                "LastStatusChange": "2026-03-07T22:59:51+00:00",
                "OutsideIpAddress": "57.180.229.172",
                "Status": "UP",
                "StatusMessage": "2 BGP ROUTES"
            }
        ]
    },
    {
        "Id": "vpn-096019f59b69613fb",
        "State": "available",
        "Tunnels": [
            {
                "AcceptedRouteCount": 2,
                "LastStatusChange": "2026-03-07T23:00:00+00:00",
                "OutsideIpAddress": "13.193.98.4",
                "Status": "UP",
                "StatusMessage": "2 BGP ROUTES"
            },
            {
                "AcceptedRouteCount": 2,
                "LastStatusChange": "2026-03-07T23:00:12+00:00",
                "OutsideIpAddress": "35.74.163.246",
                "Status": "UP",
                "StatusMessage": "2 BGP ROUTES"
            }
        ]
    }
]
```



GCP Output:
```bash
 {
  "gcp_ha_vpn_interface_0_ip": {
    "sensitive": false,
    "type": "string",
    "value": "34.183.45.1"
  },
  "gcp_ha_vpn_interface_1_ip": {
    "sensitive": false,
    "type": "string",
    "value": "34.184.42.221"
  },
  "nihonmachi_ilb_ip": {
    "sensitive": false,
    "type": "string",
    "value": "10.235.1.4"
  }
```

## Deliverable 1 - Private-only access proof
- [X] Capture internal ILB details:
```bash
gcloud compute forwarding-rules describe nihonmachi-fr01 --region us-central1
```

Output:
```bash
IPAddress: 10.235.1.4
IPProtocol: TCP
creationTimestamp: '2026-03-07T14:59:24.156-08:00'
description: ''
fingerprint: jGxWU2-6s0I=
id: '269262957534319395'
kind: compute#forwardingRule
labelFingerprint: 42WmSpB8rSM=
loadBalancingScheme: INTERNAL_MANAGED
name: nihonmachi-fr01
network: https://www.googleapis.com/compute/v1/projects/taaops/global/networks/nihonmachi-vpc01
networkTier: PREMIUM
portRange: 443-443
region: https://www.googleapis.com/compute/v1/projects/taaops/regions/us-central1
selfLink: https://www.googleapis.com/compute/v1/projects/taaops/regions/us-central1/forwardingRules/nihonmachi-fr01
selfLinkWithId: https://www.googleapis.com/compute/v1/projects/taaops/regions/us-central1/forwardingRules/269262957534319395
subnetwork: https://www.googleapis.com/compute/v1/projects/taaops/regions/us-central1/subnetworks/nihonmachi-subnet01
target: https://www.googleapis.com/compute/v1/projects/taaops/regions/us-central1/targetHttpsProxies/nihonmachi-httpsproxy01
```


Instance List (final — after CRLF fix redeploy):
```bash
gcloud compute instances list --filter="name~nihonmachi-app"

NAME: nihonmachi-app-r65k
ZONE: us-central1-b
MACHINE_TYPE: e2-medium
PREEMPTIBLE: 
INTERNAL_IP: 10.235.1.3
EXTERNAL_IP: 
STATUS: RUNNING

NAME: nihonmachi-app-5x6l
ZONE: us-central1-f
MACHINE_TYPE: e2-medium
PREEMPTIBLE: 
INTERNAL_IP: 10.235.1.2
EXTERNAL_IP: 
STATUS: RUNNING
```

Backend health:
``` bash
gcloud compute backend-services get-health nihonmachi-backend01 --region us-central1

status:
  healthStatus:
  - healthState: HEALTHY
    instance: https://www.googleapis.com/compute/v1/projects/taaops/zones/us-central1-b/instances/nihonmachi-app-r65k
    ipAddress: 10.235.1.3
    port: 443
  - healthState: HEALTHY
    instance: https://www.googleapis.com/compute/v1/projects/taaops/zones/us-central1-f/instances/nihonmachi-app-5x6l
    ipAddress: 10.235.1.2
    port: 443
  kind: compute#backendServiceGroupHealth
```

- [X] From a host inside the VPN corridor, verify internal ILB access:

### Tunnel 1: INTERNAL_IP: 10.235.1.3
Test commands - use this to connect:
```bash
gcloud compute ssh nihonmachi-app-r65k --zone=us-central1-f --project=taaops --zone us-central1-b --project=taaops --tunnel-through-iap --ssh-key-file ~/.ssh/taaops_gcp
```



```bash
 curl -k https://10.235.1.3/health
ok
```

```bash
jastek_sweeney@nihonmachi-app-r65k:~$ curl -k https://10.235.1.3/
<h1>Nihonmachi Clinic (Private)</h1>
<p>Only reachable via VPN corridor.</p>
```



```bash
curl -k https://10.235.1.3/health
Last login: Thu Mar  5 08:53:36 2026 from 35.235.245.129
jastek_sweeney@nihonmachi-app-fz32:~$ curl -k https://10.235.1.3/health
ok


curl -k https://10.235.1.3/
jastek_sweeney@nihonmachi-app-fz32:~$ curl -k https://10.235.1.3/
<h1>Nihonmachi Clinic (Private)</h1>
<p>Only reachable via VPN corridor.</p>
```

### Tunnel 2: INTERNAL_IP: 10.235.1.2
```bash
gcloud compute ssh nihonmachi-app-5x6l \
  --zone=us-central1-f \
  --project=taaops \
  --tunnel-through-iap \
  --ssh-key-file ~/.ssh/taaops_gcp
```

Test:
```bash
curl -k https://10.235.1.2/health
ok

curl -k https://10.235.1.2/
<h1>Nihonmachi Clinic (Private)</h1>
<p>Only reachable via VPN corridor.</p>
```


- [X] From the public internet, show the internal ILB does not respond.
```bash

curl -k https://10.235.1.3/health
curl: (28) Failed to connect to 10.235.1.3 port 443 after 21052 ms: Could not connect to server

John Sweeney@SEBEK MINGW64 ~/aws/class7/armageddon/jastekAI/SEIR_Foundations/LAB4 (main)
$ curl -k https://10.235.1.2/health
curl: (28) Failed to connect to 10.235.1.2 port 443 after 21045 ms: Could not connect to server
```


## Deliverable 2 - MIG proof
- [X] List managed instance groups:
```bash
gcloud compute instance-groups managed list --regions us-central1
```

Output:
```bash
NAME: nihonmachi-mig01
LOCATION: us-central1
SCOPE: region
BASE_INSTANCE_NAME: nihonmachi-app
SIZE: 2
TARGET_SIZE: 2
INSTANCE_TEMPLATE: nihonmachi-tpl01-20260307225735043200000001
AUTOSCALED: no
```

- [X] List app instances:
```bash
gcloud compute instances list --filter="name~nihonmachi-app"
```

Output:
```bash
NAME: nihonmachi-app-r65k
ZONE: us-central1-b
MACHINE_TYPE: e2-medium
PREEMPTIBLE: 
INTERNAL_IP: 10.235.1.3
EXTERNAL_IP: 
STATUS: RUNNING

NAME: nihonmachi-app-5x6l
ZONE: us-central1-f
MACHINE_TYPE: e2-medium
PREEMPTIBLE: 
INTERNAL_IP: 10.235.1.2
EXTERNAL_IP: 
STATUS: RUNNING
```

## Deliverable 3 - Tokyo RDS connectivity proof

The test script (`/usr/local/bin/rds_test.py`) and env profile (`/etc/profile.d/tokyo_rds.sh`) are installed by the GCP VM startup script at boot.

**Step 1 — SSH into one of the running VMs via IAP:**
```bash
gcloud compute ssh nihonmachi-app-r65k --zone=us-central1-b --project=taaops --tunnel-through-iap --ssh-key-file ~/.ssh/taaops_gcp
```

**Step 2 — On the VM, source the profile and verify env vars:**
```bash
# Load what the startup script wrote (RDS host, port, user, password, DB)
source /etc/profile.d/tokyo_rds.sh

# Safety net: re-fetch password if profile was written before the GCP secret existed
[ -z "$TOKYO_RDS_PASS" ] && export TOKYO_RDS_PASS=$(gcloud secrets versions access latest --secret=nihonmachi-tokyo-rds-password)

echo "Host : $TOKYO_RDS_HOST"
echo "User : $TOKYO_RDS_USER"
echo "DB   : $TOKYO_RDS_DB"
echo "Pass : ${#TOKYO_RDS_PASS} chars"
```

Expected values (all set correctly by startup script on current VMs):
- `Host`: `taaops-aurora-cluster-02.cluster-cziy8u28egkv.ap-northeast-1.rds.amazonaws.com`
- `User`: `admin`
- `DB`: `galactus`
- `Pass`: non-zero char count


Output:
```bash
Host : taaops-aurora-cluster-02.cluster-cziy8u28egkv.ap-northeast-1.rds.amazonaws.com
User : admin
DB   : galactus
Pass : 10 chars
```


**Step 3 — Run the connectivity test:**
```bash
python3 /usr/local/bin/rds_test.py
```

Expected JSON output:
```json
{
  "status": "ok",
  "latest_ts": "2026-03-05T..."
}
```

- [X] Submit the JSON output.

**Actual output (captured 2026-03-08 via IAP tunnel + plink from nihonmachi-app-r65k):**
```json
{
  "status": "ok",
  "latest_ts": "2026-03-08T11:56:24.921289"
}
```

**Root cause of prior failure (fixed):**
The TGW VPC attachment (`tgw-attach-0454e0d61697bb548`) only had a subnet in `ap-northeast-1a`
(`subnet-0a21ce9416d7ec3e0`, `10.233.100.0/28`). The RDS-adjacent EC2 instance used for
connectivity testing (`i-01920f6e0690b79d6`, `10.233.11.98`) sits in `ap-northeast-1c`.
Without a TGW ENI in AZ-c, return traffic from GCP could not be delivered to the instance.

**Fix applied:**
1. Created new TGW subnet `subnet-08a6b92dc59c56848` (`10.233.101.0/28`, `ap-northeast-1c`)
2. Associated it with the private route table (`rtb-07a3e2feb5fe4b375`)
3. Modified the TGW VPC attachment to include the new subnet (covers both AZ-a and AZ-c)

> **Note:** The `rds_test.py` script default DB name falls back to `galactus` if `TOKYO_RDS_DB` is unset, but the startup script exports `TOKYO_RDS_DB="galactus"` in the profile, so this is only relevant if you skip Step 2.
> Run `(cd newyork_gcp && terraform apply)` to roll the MIG instances with any future template changes.

## Deliverable 4 - Process proof (PSK discipline reminder)

### PSK Discipline — Process and Compliance Notes

1. **Generation**: All four VPN PSKs (tunnel1–tunnel4) were generated with `openssl rand -base64 48` (64-character random strings). No dictionary words, no repeated values across tunnels.

2. **Distribution (out-of-band)**: PSKs were transmitted exclusively via a separate secure channel (encrypted password manager / 1Password vault share). They were never emailed, Slacked, or committed to any Git repository.

3. **Terraform storage**: PSKs are passed to Terraform via `TF_VAR_psk_tunnel_*` environment variables set in the shell at apply time. The `terraform.tfvars` file contains only non-secret values and is safe to commit. The `.tfvars` file comment explicitly warns against hardcoding PSKs there.

4. **State file risk**: Terraform stores PSK values in the remote state file (S3). The S3 state bucket is encrypted at rest (AES-256 via SSE-S3), versioned, and access-controlled by IAM — no public access. Even so, treat state as sensitive: restrict `s3:GetObject` on the state bucket to only the Terraform IAM role and authorized operators. All four backends use `dynamodb_table = "taaops-terraform-state-lock"` for state locking, preventing concurrent apply runs from corrupting state. The DynamoDB tables are ACTIVE in both ap-northeast-1 (Tokyo/global/newyork_gcp) and sa-east-1 (São Paulo).

5. **Compliance mistakes that would violate policy**:
   - Hardcoding PSKs in `.tf` files or `.tfvars` committed to Git — violates secret hygiene and any SOC 2 / HIPAA secret-management control.
   - Logging VPN tunnel negotiation details (IKE phase 1/2 output) to CloudWatch without restriction — risk of PSK exposure in log streams.
   - Writing PHI to CloudFront access logs, ALB logs, or VPC Flow Logs — Flow Logs capture IP/port metadata only, but field-level PHI (e.g., in query strings) in ALB logs is a HIPAA violation even if traffic is over the VPN corridor.
   - Storing PHI in a local GCP database or any unencrypted datastore — violates the lab restriction "no databases in GCP" and HIPAA's encryption-at-rest requirement.

6. **Rotation discipline**: PSK rotation requires a coordinated two-step update: first update the PSK in AWS VPN tunnel configuration and GCP VPN tunnel configuration atomically, then update `TF_VAR_psk_tunnel_*` and re-run `terraform apply` to sync state. Rotation should occur on a schedule (≥ annually) or immediately upon any suspected compromise.

## Additional requirements
- [X] Translation of logs from English to Japanese

Run this command in order to trigger the conversion:
```bash
/c/Python311/python.exe python/translate_batch_audit.py --input-bucket taaops-translate-input --output-bucket taaops-translate-output --source-dir LAB4-DELIVERABLES --glob "*.json" --key-prefix lab4-deliverables --region ap-northeast-1
```

Translation explanation:

Flow: Finds all LAB4-DELIVERABLES/*.json → uploads each to S3 input bucket → Lambda translates → polls output bucket → downloads as -jpn suffix files to localized  

command |	Explanation
/c/Python311/python.exe |	Full path to Python 3.11 executable on Windows (C: drive mapped to /c/)
translate_batch_audit.py |	The batch translation driver script — processes multiple files and delegates to translate_via_s3.py per file
--input-bucket taaops-translate-input |	S3 bucket where files are uploaded for Lambda to process
--output-bucket taaops-translate-output |	S3 bucket where Lambda stores translated results
--source-dir LAB4-DELIVERABLES	| Local directory containing the source files to translate
--glob "*.json"	 | File pattern — match all .json files in LAB4-DELIVERABLES
--key-prefix lab4-deliverables	| S3 key path prefix — uploaded files go to s3://taaops-translate-input/lab4-deliverables/*
--region ap-northeast-1 |	AWS region (Tokyo) where the translation Lambda and S3 buckets are located


## Restrictions reminders
- [X] No databases in GCP
- [X] No PHI in logs
- [X] Only private access over VPN corridor
- [X] Passwords/secrets must not be hardcoded in TF or Git


## Break-Glass CloudFront Cache Invalidation

Clears the CloudFront cache in an emergency (bad deploy, cache poisoning, stale content). Two options:

### Option 1 — Shell script (fastest, no Terraform state required)

Reads the distribution ID automatically from remote state or `LAB4-DELIVERABLES/global-outputs.json`, then calls the AWS API directly.

```bash
# From LAB4 root — invalidate everything
bash scripts/order66.sh

# Targeted paths
bash scripts/order66.sh "/images/*" "/api/*" "/index.html"
```

The script prompts for confirmation before calling:
```bash
aws cloudfront create-invalidation \
  --distribution-id <DIST_ID> \
  --invalidation-batch '{ "Paths": { "Quantity": N, "Items": [...] }, "CallerReference": "break-glass-<ts>" }'
```

### Option 2 — Terraform action block (tied to `global` apply, creates audit trail)

```bash
cd global
terraform apply -var='break_glass_paths=["/*"]'
# or specific paths:
terraform apply -var='break_glass_paths=["/images/*","/index.html"]'
```

> **Why the script is preferred for break-glass:** It fires in seconds. Terraform requires a plan/apply cycle and a clean state lock. Use the Terraform action when you want the invalidation recorded in a deployment pipeline.

### Testing order66.sh

**Step 1 — Run with a targeted path** (cheaper than `/*`, same code path):
```bash
# From LAB4 root
source .secrets.env
bash scripts/order66.sh "/static/placeholder.png"
# Type 'yes' at the prompt.
# Output: a table with an invalidation ID and status InProgress.
```

**Step 2 — Verify the invalidation completed:**
```bash
aws cloudfront list-invalidations \
  --distribution-id $(cd global && terraform output -raw cloudfront_distribution_id) \
  --query "InvalidationList.Items[0].{Id:Id,Status:Status,CreateTime:CreateTime}" \
  --output table
# Status should flip from InProgress → Completed within ~30-60 seconds.
```

**Step 3 — Confirm cache was busted:**

Test:
The test was run against the static image as opposed to index.html. Inside the user data the image has a stable mtime (touch -t 202602070000) specifically designated "for cache tests"
It's a deterministic binary asset — a cache hit vs miss is unambiguous (check Content-Length and x-cache).
/index.html is generated dynamically by Flask, so CloudFront may not cache it at all depending on the cache behavior settings (e.g. dynamic responses with Cache-Control: no-cache won't be cached)


```bash
CF_DOMAIN=$(cd global && terraform output -raw cloudfront_distribution_domain_name)
curl -sI "https://${CF_DOMAIN}/static/placeholder.png" | grep -i "x-cache\|age:"
# Expected on first hit after invalidation:
#   X-Cache: Miss from cloudfront        ← cache was busted, origin was hit
# Second hit re-caches the object:
curl -sI "https://${CF_DOMAIN}/static/placeholder.png" | grep -i "x-cache\|age:"
#   X-Cache: RefreshHit from cloudfront  ← re-cached successfully
```

> **Verified output (2026-03-10):** Invalidation `IEQGERT8FRJWC8CA3QBIZEMFX6` completed, Miss then RefreshHit confirmed on `E313MTDIOOC9AQ`.

> **⚠️ Git Bash / Windows gotcha — MSYS path conversion:**
> Git Bash automatically converts POSIX-style paths (e.g. `/static/placeholder.png`) into Windows paths
> (e.g. `C:/Program Files/Git/static/placeholder.png`) before passing them to native Windows binaries like `aws.exe`.
> This causes `InvalidArgument` errors from CloudFront because the path is no longer a valid invalidation path.
>
> **Fix:** `order66.sh` sets `MSYS_NO_PATHCONV=1` and `MSYS2_ARG_CONV_EXCL="*"` at the top of the script to
> disable this conversion globally. **Any other script or one-liner that passes CloudFront paths (or similar
> URL-style `/` paths) to AWS CLI from Git Bash must do the same**, or prefix the export before the command:
> ```bash
> MSYS_NO_PATHCONV=1 aws cloudfront create-invalidation --paths "/static/*"
> ```

---


## Standard Cleanup commands:

S3 Bucket - State bucket:

> **Why `terraform_destroy.sh` does not delete the state bucket:**
> The state bucket (`taaops-terraform-state-saopaulo`, `taaops-terraform-state-tokyo`) is a **bootstrap resource** — it is referenced only in `backend.tf` as a configuration parameter, not declared as a `resource "aws_s3_bucket"` block in any stack. Terraform only destroys resources it tracks in state. Additionally, Terraform cannot delete the bucket it is actively reading state from mid-operation. The manual cleanup below must be run **after** destroy completes.

If versioning is enabled - to delete all versions and delete markers before you can remove the bucket:
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


Short version if versioning is off or not concerned about the versions:
```bash
aws s3 rb s3://taaops-terraform-state-saopaulo --force --region sa-east-1
```