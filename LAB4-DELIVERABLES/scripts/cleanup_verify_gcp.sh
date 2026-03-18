#!/usr/bin/env bash
# cleanup_verify_gcp.sh — Post-destroy GCP resource verification for LAB4 newyork_gcp stack
#
# Checks GCP project for leftover nihonmachi / gcp-to-aws resources that would
# block or corrupt a fresh terraform_startup.sh run.
#
# Usage:
#   ./cleanup_verify_gcp.sh
#   GCP_PROJECT=taaops GCP_REGION=us-central1 ./cleanup_verify_gcp.sh
#
# Prerequisites:
#   gcloud auth application-default login (or GOOGLE_APPLICATION_CREDENTIALS set)
#
# Exit codes:
#   0 — all checks clean (or warn only)
#   1 — one or more DIRTY resources found

set -uo pipefail

GCP_PROJECT="${GCP_PROJECT:-taaops}"
GCP_REGION="${GCP_REGION:-us-central1}"

DIRTY=0
WARN=0

# ── helpers ──────────────────────────────────────────────────────────────────

RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

clean()  { echo -e "${GREEN}  CLEAN${NC}  $*"; }
dirty()  { echo -e "${RED}  DIRTY${NC}  $*"; DIRTY=1; }
warn()   { echo -e "${YELLOW}  WARN ${NC}  $*"; WARN=1; }
header() { echo -e "\n${CYAN}=== $* ===${NC}"; }

gcloud_count() {
  # Count non-empty lines from gcloud list output (minus header)
  echo "$1" | grep -c "^[a-zA-Z0-9]" 2>/dev/null || echo 0
}

echo "Project: ${GCP_PROJECT}   Region: ${GCP_REGION}"
echo "Checking gcloud authentication..."
if ! gcloud auth print-access-token --project="$GCP_PROJECT" >/dev/null 2>&1; then
  echo -e "${RED}ERROR: gcloud not authenticated. Run: gcloud auth application-default login${NC}"
  exit 1
fi

# ── VPC Network ──────────────────────────────────────────────────────────────

header "VPC Networks"
VPC_OUT=$(gcloud compute networks list \
  --project="$GCP_PROJECT" \
  --filter="name:nihonmachi" \
  --format="table(name,subnetMode,autoCreateSubnetworks)" 2>&1)
VPC_COUNT=$(gcloud compute networks list \
  --project="$GCP_PROJECT" \
  --filter="name:nihonmachi" \
  --format="value(name)" 2>/dev/null | grep -v "^$" | wc -l | tr -d "[:space:]")
echo "$VPC_OUT"
if [[ "$VPC_COUNT" -eq 0 ]]; then
  clean "No nihonmachi VPCs found"
else
  dirty "$VPC_COUNT nihonmachi VPC(s) found — delete before redeploying (subnets must be deleted first)"
fi

# ── Subnets ──────────────────────────────────────────────────────────────────

header "Subnets (${GCP_REGION})"
SUBNET_OUT=$(gcloud compute networks subnets list \
  --project="$GCP_PROJECT" \
  --regions="$GCP_REGION" \
  --filter="name:nihonmachi" \
  --format="table(name,region,ipCidrRange,network)" 2>&1)
SUBNET_COUNT=$(gcloud compute networks subnets list \
  --project="$GCP_PROJECT" \
  --regions="$GCP_REGION" \
  --filter="name:nihonmachi" \
  --format="value(name)" 2>/dev/null | grep -v "^$" | wc -l | tr -d "[:space:]")
echo "$SUBNET_OUT"
if [[ "$SUBNET_COUNT" -eq 0 ]]; then
  clean "No nihonmachi subnets found"
else
  dirty "$SUBNET_COUNT nihonmachi subnet(s) found"
fi

# ── MIG + Instance Templates ─────────────────────────────────────────────────

header "Managed Instance Group (MIG)"
MIG_OUT=$(gcloud compute instance-groups managed list \
  --project="$GCP_PROJECT" \
  --regions="$GCP_REGION" \
  --filter="name:nihonmachi" \
  --format="table(name,region,targetSize,status.stateful.hasStatefulConfig)" 2>&1)
MIG_COUNT=$(gcloud compute instance-groups managed list \
  --project="$GCP_PROJECT" \
  --regions="$GCP_REGION" \
  --filter="name:nihonmachi" \
  --format="value(name)" 2>/dev/null | grep -v "^$" | wc -l | tr -d "[:space:]")
echo "$MIG_OUT"
if [[ "$MIG_COUNT" -eq 0 ]]; then
  clean "No nihonmachi MIGs found"
else
  dirty "$MIG_COUNT nihonmachi MIG(s) found — must be deleted before removing instance template"
fi

header "Instance Templates"
TPL_OUT=$(gcloud compute instance-templates list \
  --project="$GCP_PROJECT" \
  --filter="name:nihonmachi" \
  --format="table(name,creationTimestamp,properties.machineType)" 2>&1)
TPL_COUNT=$(gcloud compute instance-templates list \
  --project="$GCP_PROJECT" \
  --filter="name:nihonmachi" \
  --format="value(name)" 2>/dev/null | grep -v "^$" | wc -l | tr -d "[:space:]")
echo "$TPL_OUT"
if [[ "$TPL_COUNT" -eq 0 ]]; then
  clean "No nihonmachi instance templates found"
else
  dirty "$TPL_COUNT nihonmachi instance template(s) found"
fi

# ── ILB Resources ────────────────────────────────────────────────────────────

header "Forwarding Rules (ILB)"
FR_OUT=$(gcloud compute forwarding-rules list \
  --project="$GCP_PROJECT" \
  --regions="$GCP_REGION" \
  --filter="name:nihonmachi" \
  --format="table(name,region,IPAddress,target)" 2>&1)
FR_COUNT=$(gcloud compute forwarding-rules list \
  --project="$GCP_PROJECT" \
  --regions="$GCP_REGION" \
  --filter="name:nihonmachi" \
  --format="value(name)" 2>/dev/null | grep -v "^$" | wc -l | tr -d "[:space:]")
echo "$FR_OUT"
if [[ "$FR_COUNT" -eq 0 ]]; then
  clean "No nihonmachi forwarding rules found"
else
  dirty "$FR_COUNT nihonmachi forwarding rule(s) found"
fi

header "Backend Services"
BS_OUT=$(gcloud compute backend-services list \
  --project="$GCP_PROJECT" \
  --filter="name:nihonmachi region:$GCP_REGION" \
  --format="table(name,region,loadBalancingScheme,protocol)" 2>&1)
BS_COUNT=$(gcloud compute backend-services list \
  --project="$GCP_PROJECT" \
  --filter="name:nihonmachi region:$GCP_REGION" \
  --format="value(name)" 2>/dev/null | grep -v "^$" | wc -l | tr -d "[:space:]")
echo "$BS_OUT"
if [[ "$BS_COUNT" -eq 0 ]]; then
  clean "No nihonmachi backend services found"
else
  dirty "$BS_COUNT nihonmachi backend service(s) found"
fi

header "Health Checks"
HC_OUT=$(gcloud compute health-checks list \
  --project="$GCP_PROJECT" \
  --filter="name:nihonmachi" \
  --format="table(name,type,region)" 2>&1)
HC_COUNT=$(gcloud compute health-checks list \
  --project="$GCP_PROJECT" \
  --filter="name:nihonmachi" \
  --format="value(name)" 2>/dev/null | grep -v "^$" | wc -l | tr -d "[:space:]")
echo "$HC_OUT"
if [[ "$HC_COUNT" -eq 0 ]]; then
  clean "No nihonmachi health checks found"
else
  dirty "$HC_COUNT nihonmachi health check(s) found"
fi

# ── VPN Resources ─────────────────────────────────────────────────────────────

header "VPN Tunnels (tunnel00-03)"
VPN_OUT=$(gcloud compute vpn-tunnels list \
  --project="$GCP_PROJECT" \
  --regions="$GCP_REGION" \
  --filter="name:tunnel0" \
  --format="table(name,region,status,peerIp,ikeVersion)" 2>&1)
VPN_COUNT=$(gcloud compute vpn-tunnels list \
  --project="$GCP_PROJECT" \
  --regions="$GCP_REGION" \
  --filter="name:tunnel0" \
  --format="value(name)" 2>/dev/null | grep -v "^$" | wc -l | tr -d "[:space:]")
echo "$VPN_OUT"
if [[ "$VPN_COUNT" -eq 0 ]]; then
  clean "No lab VPN tunnels found"
else
  dirty "$VPN_COUNT VPN tunnel(s) found (tunnel00-03) — delete before redeploying"
fi

header "HA VPN Gateways"
HAVPN_OUT=$(gcloud compute vpn-gateways list \
  --project="$GCP_PROJECT" \
  --regions="$GCP_REGION" \
  --filter="name:gcp-to-aws" \
  --format="table(name,region,network)" 2>&1)
HAVPN_COUNT=$(gcloud compute vpn-gateways list \
  --project="$GCP_PROJECT" \
  --regions="$GCP_REGION" \
  --filter="name:gcp-to-aws" \
  --format="value(name)" 2>/dev/null | grep -v "^$" | wc -l | tr -d "[:space:]")
echo "$HAVPN_OUT"
if [[ "$HAVPN_COUNT" -eq 0 ]]; then
  clean "No gcp-to-aws VPN gateways found"
else
  dirty "$HAVPN_COUNT gcp-to-aws VPN gateway/gateways found"
fi

header "External VPN Gateways"
EXTVPN_OUT=$(gcloud compute external-vpn-gateways list \
  --project="$GCP_PROJECT" \
  --filter="name:gcp-to-aws" \
  --format="table(name,redundancyType)" 2>&1)
EXTVPN_COUNT=$(gcloud compute external-vpn-gateways list \
  --project="$GCP_PROJECT" \
  --filter="name:gcp-to-aws" \
  --format="value(name)" 2>/dev/null | grep -v "^$" | wc -l | tr -d "[:space:]")
echo "$EXTVPN_OUT"
if [[ "$EXTVPN_COUNT" -eq 0 ]]; then
  clean "No gcp-to-aws external VPN gateways found"
else
  dirty "$EXTVPN_COUNT external VPN gateway(s) found"
fi

header "Cloud Routers"
ROUTER_OUT=$(gcloud compute routers list \
  --project="$GCP_PROJECT" \
  --regions="$GCP_REGION" \
  --filter="name:nihonmachi OR name:gcp-to-aws" \
  --format="table(name,region,network)" 2>&1)
ROUTER_COUNT=$(gcloud compute routers list \
  --project="$GCP_PROJECT" \
  --regions="$GCP_REGION" \
  --filter="name:nihonmachi OR name:gcp-to-aws" \
  --format="value(name)" 2>/dev/null | grep -v "^$" | wc -l | tr -d "[:space:]")
echo "$ROUTER_OUT"
if [[ "$ROUTER_COUNT" -eq 0 ]]; then
  clean "No lab cloud routers found"
else
  dirty "$ROUTER_COUNT lab cloud router(s) found"
fi

# ── Firewall Rules ────────────────────────────────────────────────────────────

header "Firewall Rules"
FW_OUT=$(gcloud compute firewall-rules list \
  --project="$GCP_PROJECT" \
  --filter="name:nihonmachi OR name:allow-iap-ssh-vpc01 OR name:allow-vpn-traffic" \
  --format="table(name,direction,priority,network)" 2>&1)
FW_COUNT=$(gcloud compute firewall-rules list \
  --project="$GCP_PROJECT" \
  --filter="name:nihonmachi OR name:allow-iap-ssh-vpc01 OR name:allow-vpn-traffic" \
  --format="value(name)" 2>/dev/null | grep -v "^$" | wc -l | tr -d "[:space:]")
echo "$FW_OUT"
if [[ "$FW_COUNT" -eq 0 ]]; then
  clean "No lab firewall rules found"
else
  warn "$FW_COUNT lab firewall rule(s) found — deleted automatically with VPC, but orphaned if VPC already gone"
fi

# ── Secret Manager ────────────────────────────────────────────────────────────

header "Secret Manager Secrets"
SECRET_OUT=$(gcloud secrets list \
  --project="$GCP_PROJECT" \
  --filter="name:nihonmachi" \
  --format="table(name,createTime,replication.automatic)" 2>&1)
SECRET_COUNT=$(gcloud secrets list \
  --project="$GCP_PROJECT" \
  --filter="name:nihonmachi" \
  --format="value(name)" 2>/dev/null | grep -v "^$" | wc -l | tr -d "[:space:]")
echo "$SECRET_OUT"
if [[ "$SECRET_COUNT" -eq 0 ]]; then
  clean "No nihonmachi secrets found"
else
  warn "$SECRET_COUNT nihonmachi secret(s) found — Terraform will error on create if already exists with same name"
fi

# ── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "════════════════════════════════════════"
if [[ "$DIRTY" -eq 1 ]]; then
  echo -e "${RED}RESULT: DIRTY — leftover GCP resources found. Clean up before running terraform_startup.sh.${NC}"
  exit 1
elif [[ "$WARN" -eq 1 ]]; then
  echo -e "${YELLOW}RESULT: WARN — minor items found, review above. Redeploy may still work.${NC}"
  exit 0
else
  echo -e "${GREEN}RESULT: CLEAN — no blocking GCP resources found. Safe to run terraform_startup.sh.${NC}"
  exit 0
fi
