# diagnostics/

Parameterized diagnostic scripts for the LAB4 multi-region stack.
All IDs (TGW, VPC, attachment, instances, GCP VM) are **resolved at runtime** —
no hardcoded resource IDs from a previous deploy.

## Prerequisites

- `source .secrets.env` from the LAB4 root (sets AWS credentials + PATH)
- `LAB4-DELIVERABLES/tokyo-outputs.json` and `newyork-gcp-outputs.json` must exist  
  (produced by `terraform_startup.sh` — see `DEPLOYMENT_GUIDE.md`)
- For GCP scripts: `gcloud` must be in PATH, or set `GCLOUD_PATH=/path/to/gcloud`
- For `rds_reachability.py`: `plink.exe` must be alongside the gcloud SDK  
  (set `PLINK_PATH=/path/to/plink.exe` to override)

## Scripts

| Script | What it checks | Needs GCP |
|--------|---------------|-----------|
| `vpn_status.py` | AWS VPN tunnel state, BGP telemetry, TGW VPN attachments | No |
| `tgw_routes.py` | TGW route table deep-dive (routes, associations, propagations) | No |
| `vpc_routing.py` | Tokyo VPC subnets, route tables, TGW routes to GCP CIDR | No |
| `tgw_health.py` | TGW VPC attachment subnets, AZ coverage gaps, running instances | No |
| `gcp_vpn.py` | GCP HA VPN tunnels, BGP sessions, cloud routers, routes | Yes |
| `gcp_infra.py` | GCP firewall rules, MIG state, backend health, instance detail | Yes |
| `ssm_gcp_ping.py` | SSM → TCP probe from Tokyo EC2 → GCP ILB (connectivity test) | No |
| `rds_reachability.py` | Run rds_test.py on GCP VM via IAP tunnel (end-to-end DB test) | Yes |
| `tgw_connectivity.py` | Wait for TGW attachment to become available, then SSM ping GCP | No |

## Quick usage

```bash
# From LAB4 root
source .secrets.env
cd diagnostics

# Check VPN tunnels
python vpn_status.py

# Check TGW route tables (all discovered automatically)
python tgw_routes.py

# Test GCP reachability from any running Tokyo instance
python ssm_gcp_ping.py

# Override source instance
python ssm_gcp_ping.py --instance-id i-0abc123

# Check GCP VPN/BGP status
python gcp_vpn.py

# Run rds_test.py on GCP VM end-to-end
python rds_reachability.py

# Fresh deploy: wait for TGW then ping GCP
python tgw_connectivity.py

# Skip the wait if the stack is already up
python tgw_connectivity.py --skip-wait
```

## How IDs are resolved

1. **TGW ID / VPC ID / RDS endpoint** — read from `LAB4-DELIVERABLES/tokyo-outputs.json`
2. **GCP ILB IP** — read from `LAB4-DELIVERABLES/newyork-gcp-outputs.json`
3. **TGW route tables** — `describe-transit-gateway-route-tables --filter transit-gateway-id=<tgw_id>`
4. **TGW VPC attachment** — `describe-transit-gateway-vpc-attachments --filter vpc-id=<vpc_id>`
5. **EC2 instances** — `describe-instances --filter vpc-id=<vpc_id> state=running`
6. **GCP VM name** — `gcloud compute instances list --filter=name~nihonmachi-app`

## Shared helpers

`_config.py` contains all discovery functions and is imported by every script.
You can also import it directly for interactive use:

```python
from diagnostics._config import get_tgw_id, get_vpc_id, aws
print(aws(["ec2", "describe-vpn-connections", "--output", "json"]))
```

## Archived one-off scripts

Scripts that were specific to a single debugging session (hardcoded resource IDs
from a now-destroyed stack) are in `archive/tokyo-debug-scripts/`:

- `tf_unlock.py` — force-unlocked a specific state lock
- `tf_import.py` / `tf_import2.py` — imported specific resources into Terraform state
- `aws_tgw_fix.py` — created the AZ-c TGW subnet (fix already applied in Terraform)
- `aws_tgw_fix_plan.py` — dry-run planning for the above fix
