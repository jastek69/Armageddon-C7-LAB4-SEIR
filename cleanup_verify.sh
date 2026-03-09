#!/usr/bin/env bash
# cleanup_verify.sh — Post-destroy resource verification for LAB4
#
# Checks ap-northeast-1 (Tokyo) and sa-east-1 (Sao Paulo) for leftover
# resources that would block or corrupt a fresh terraform_startup.sh run.
#
# Usage:
#   ./cleanup_verify.sh               # check both regions
#   REGION=ap-northeast-1 ./cleanup_verify.sh  # one region only
#
# Exit codes:
#   0 — all checks clean
#   1 — one or more DIRTY resources found

set -uo pipefail

TOKYO_REGION="${TOKYO_REGION:-ap-northeast-1}"
SAO_REGION="${SAO_REGION:-sa-east-1}"
CHECK_SAO="${CHECK_SAO:-true}"

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

count_resources() {
  # Returns count of non-empty lines in AWS CLI output (excluding header/divider lines)
  echo "$1" | grep -cve '^\s*$' -e '^-' -e '^|.*---|' -e '^None$' 2>/dev/null || echo 0
}

# ── Tokyo checks ─────────────────────────────────────────────────────────────

header "Tokyo (${TOKYO_REGION}) — Transit Gateways"
TGW_OUT=$(aws ec2 describe-transit-gateways \
  --region "$TOKYO_REGION" \
  --query "TransitGateways[?State!='deleted'].{ID:TransitGatewayId,State:State,Name:Tags[?Key=='Name']|[0].Value}" \
  --output table 2>&1)
TGW_COUNT=$(aws ec2 describe-transit-gateways \
  --region "$TOKYO_REGION" \
  --query "length(TransitGateways[?State!='deleted'])" \
  --output text 2>/dev/null || echo 0)
echo "$TGW_OUT"
if [[ "$TGW_COUNT" -eq 0 ]]; then
  clean "$TGW_COUNT TGW(s) found"
elif [[ "$TGW_COUNT" -eq 1 ]]; then
  warn "$TGW_COUNT TGW found — OK if this is intentional pre-existing; will be replaced by Terraform"
else
  dirty "$TGW_COUNT TGW(s) found — delete extras before redeploying (only 1 expected)"
fi

header "Tokyo (${TOKYO_REGION}) — VPCs"
VPC_OUT=$(aws ec2 describe-vpcs \
  --region "$TOKYO_REGION" \
  --query "Vpcs[?!IsDefault].{ID:VpcId,CIDR:CidrBlock,Name:Tags[?Key=='Name']|[0].Value}" \
  --output table 2>&1)
VPC_COUNT=$(aws ec2 describe-vpcs \
  --region "$TOKYO_REGION" \
  --query "length(Vpcs[?!IsDefault])" \
  --output text 2>/dev/null || echo 0)
echo "$VPC_OUT"
if [[ "$VPC_COUNT" -eq 0 ]]; then
  clean "No non-default VPCs found"
else
  dirty "$VPC_COUNT non-default VPC(s) found — delete before redeploying"
fi

header "Tokyo (${TOKYO_REGION}) — VPN Connections"
VPN_OUT=$(aws ec2 describe-vpn-connections \
  --region "$TOKYO_REGION" \
  --query "VpnConnections[?State!='deleted'].{ID:VpnConnectionId,State:State,TGW:TransitGatewayId,AttachID:TransitGatewayAttachmentId}" \
  --output table 2>&1)
VPN_COUNT=$(aws ec2 describe-vpn-connections \
  --region "$TOKYO_REGION" \
  --query "length(VpnConnections[?State!='deleted'])" \
  --output text 2>/dev/null || echo 0)
echo "$VPN_OUT"
if [[ "$VPN_COUNT" -eq 0 ]]; then
  clean "No active VPN connections found"
else
  dirty "$VPN_COUNT VPN connection(s) found — delete before redeploying"
fi

header "Tokyo (${TOKYO_REGION}) — Customer Gateways"
CGW_OUT=$(aws ec2 describe-customer-gateways \
  --region "$TOKYO_REGION" \
  --query "CustomerGateways[?State!='deleted'].{ID:CustomerGatewayId,IP:IpAddress,ASN:BgpAsn,Name:Tags[?Key=='Name']|[0].Value}" \
  --output table 2>&1)
CGW_COUNT=$(aws ec2 describe-customer-gateways \
  --region "$TOKYO_REGION" \
  --query "length(CustomerGateways[?State!='deleted'])" \
  --output text 2>/dev/null || echo 0)
echo "$CGW_OUT"
if [[ "$CGW_COUNT" -eq 0 ]]; then
  clean "No customer gateways found"
else
  dirty "$CGW_COUNT customer gateway(s) found — these persist after VPN deletion, delete manually"
fi

header "Tokyo (${TOKYO_REGION}) — NAT Gateways"
NAT_OUT=$(aws ec2 describe-nat-gateways \
  --region "$TOKYO_REGION" \
  --filter "Name=state,Values=available,pending" \
  --query "NatGateways[*].{ID:NatGatewayId,State:State,VPC:VpcId,Subnet:SubnetId}" \
  --output table 2>&1)
NAT_COUNT=$(aws ec2 describe-nat-gateways \
  --region "$TOKYO_REGION" \
  --filter "Name=state,Values=available,pending" \
  --query "length(NatGateways)" \
  --output text 2>/dev/null || echo 0)
echo "$NAT_OUT"
if [[ "$NAT_COUNT" -eq 0 ]]; then
  clean "No active NAT gateways found"
else
  dirty "$NAT_COUNT NAT gateway(s) still active — costing ~\$32/mo each, delete immediately"
fi

header "Tokyo (${TOKYO_REGION}) — Unassociated Elastic IPs"
EIP_OUT=$(aws ec2 describe-addresses \
  --region "$TOKYO_REGION" \
  --query "Addresses[?AssociationId==null].{AllocationId:AllocationId,IP:PublicIp,Name:Tags[?Key=='Name']|[0].Value}" \
  --output table 2>&1)
EIP_COUNT=$(aws ec2 describe-addresses \
  --region "$TOKYO_REGION" \
  --query "length(Addresses[?AssociationId==null])" \
  --output text 2>/dev/null || echo 0)
echo "$EIP_OUT"
if [[ "$EIP_COUNT" -eq 0 ]]; then
  clean "No unassociated EIPs found"
else
  dirty "$EIP_COUNT unassociated EIP(s) found — release to avoid charges"
fi

header "Tokyo (${TOKYO_REGION}) — RDS Clusters"
RDS_OUT=$(aws rds describe-db-clusters \
  --region "$TOKYO_REGION" \
  --query "DBClusters[*].{ID:DBClusterIdentifier,Status:Status,Engine:Engine}" \
  --output table 2>&1)
RDS_COUNT=$(aws rds describe-db-clusters \
  --region "$TOKYO_REGION" \
  --query "length(DBClusters)" \
  --output text 2>/dev/null || echo 0)
echo "$RDS_OUT"
if [[ "$RDS_COUNT" -eq 0 ]]; then
  clean "No RDS clusters found"
else
  dirty "$RDS_COUNT RDS cluster(s) found — delete before redeploying"
fi

header "Tokyo (${TOKYO_REGION}) — Load Balancers"
ALB_OUT=$(aws elbv2 describe-load-balancers \
  --region "$TOKYO_REGION" \
  --query "LoadBalancers[*].{Name:LoadBalancerName,State:State.Code,DNS:DNSName}" \
  --output table 2>&1)
ALB_COUNT=$(aws elbv2 describe-load-balancers \
  --region "$TOKYO_REGION" \
  --query "length(LoadBalancers)" \
  --output text 2>/dev/null || echo 0)
echo "$ALB_OUT"
if [[ "$ALB_COUNT" -eq 0 ]]; then
  clean "No load balancers found"
else
  dirty "$ALB_COUNT load balancer(s) found"
fi

header "Tokyo (${TOKYO_REGION}) — Lambda Functions (lab)"
LAMBDA_OUT=$(aws lambda list-functions \
  --region "$TOKYO_REGION" \
  --query "Functions[?contains(FunctionName,'tokyo') || contains(FunctionName,'taaops') || contains(FunctionName,'nihonmachi')].{Name:FunctionName,Runtime:Runtime}" \
  --output table 2>&1)
LAMBDA_COUNT=$(aws lambda list-functions \
  --region "$TOKYO_REGION" \
  --query "length(Functions[?contains(FunctionName,'tokyo') || contains(FunctionName,'taaops') || contains(FunctionName,'nihonmachi')])" \
  --output text 2>/dev/null || echo 0)
echo "$LAMBDA_OUT"
if [[ "$LAMBDA_COUNT" -eq 0 ]]; then
  clean "No lab Lambda functions found"
else
  warn "$LAMBDA_COUNT lab Lambda function(s) found — delete if redeploying from scratch"
fi

header "Tokyo (${TOKYO_REGION}) — Route53 Private Hosted Zones"
R53_OUT=$(aws route53 list-hosted-zones \
  --query "HostedZones[?Config.PrivateZone==\`true\`].{Name:Name,ID:Id,Records:ResourceRecordSetCount}" \
  --output table 2>&1)
R53_COUNT=$(aws route53 list-hosted-zones \
  --query "length(HostedZones[?Config.PrivateZone==\`true\`])" \
  --output text 2>/dev/null || echo 0)
echo "$R53_OUT"
if [[ "$R53_COUNT" -eq 0 ]]; then
  clean "No private hosted zones found"
else
  dirty "$R53_COUNT private hosted zone(s) found — Terraform will conflict on create"
fi

header "Tokyo (${TOKYO_REGION}) — S3 Buckets (non-backend)"
S3_ALL=$(aws s3api list-buckets \
  --query "Buckets[?contains(Name,'taaops') || contains(Name,'tokyo') || contains(Name,'nihonmachi')].Name" \
  --output text 2>/dev/null || echo "")
S3_LAB=$(echo "$S3_ALL" | tr '\t' '\n' | grep -v "taaops-terraform-state-tokyo" | grep -v "^$" || true)
S3_COUNT=$(echo "$S3_LAB" | grep -v "^$" | wc -l | tr -d '[:space:]')
if [[ -n "$S3_LAB" ]]; then
  echo "$S3_LAB"
fi
if [[ "$S3_COUNT" -eq 0 ]]; then
  clean "No non-backend lab S3 buckets found"
else
  warn "$S3_COUNT lab S3 bucket(s) found (excluding state backend) — empty and delete before redeploying"
  echo "$S3_LAB"
fi

# ── Sao Paulo checks ─────────────────────────────────────────────────────────

if [[ "$CHECK_SAO" == "true" ]]; then
  header "Sao Paulo (${SAO_REGION}) — VPCs"
  SAO_VPC_COUNT=$(aws ec2 describe-vpcs \
    --region "$SAO_REGION" \
    --query "length(Vpcs[?!IsDefault])" \
    --output text 2>/dev/null || echo 0)
  aws ec2 describe-vpcs \
    --region "$SAO_REGION" \
    --query "Vpcs[?!IsDefault].{ID:VpcId,CIDR:CidrBlock,Name:Tags[?Key=='Name']|[0].Value}" \
    --output table 2>/dev/null || true
  if [[ "$SAO_VPC_COUNT" -eq 0 ]]; then
    clean "No non-default VPCs in Sao Paulo"
  else
    dirty "$SAO_VPC_COUNT non-default VPC(s) in Sao Paulo"
  fi

  header "Sao Paulo (${SAO_REGION}) — NAT Gateways"
  SAO_NAT_COUNT=$(aws ec2 describe-nat-gateways \
    --region "$SAO_REGION" \
    --filter "Name=state,Values=available,pending" \
    --query "length(NatGateways)" \
    --output text 2>/dev/null || echo 0)
  if [[ "$SAO_NAT_COUNT" -eq 0 ]]; then
    clean "No active NAT gateways in Sao Paulo"
  else
    dirty "$SAO_NAT_COUNT NAT gateway(s) still active in Sao Paulo"
    aws ec2 describe-nat-gateways \
      --region "$SAO_REGION" \
      --filter "Name=state,Values=available,pending" \
      --query "NatGateways[*].{ID:NatGatewayId,State:State,VPC:VpcId}" \
      --output table 2>/dev/null || true
  fi

  header "Sao Paulo (${SAO_REGION}) — TGW Peering Attachments"
  SAO_PEER_COUNT=$(aws ec2 describe-transit-gateway-peering-attachments \
    --region "$SAO_REGION" \
    --query "length(TransitGatewayPeeringAttachments[?State!='deleted'])" \
    --output text 2>/dev/null || echo 0)
  if [[ "$SAO_PEER_COUNT" -eq 0 ]]; then
    clean "No active TGW peering attachments in Sao Paulo"
  else
    dirty "$SAO_PEER_COUNT TGW peering attachment(s) in Sao Paulo"
  fi
fi

# ── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "════════════════════════════════════════"
if [[ "$DIRTY" -eq 1 ]]; then
  echo -e "${RED}RESULT: DIRTY — leftover resources found. Clean up before running terraform_startup.sh.${NC}"
  exit 1
elif [[ "$WARN" -eq 1 ]]; then
  echo -e "${YELLOW}RESULT: WARN — minor items found, review above. Redeploy may still work.${NC}"
  exit 0
else
  echo -e "${GREEN}RESULT: CLEAN — no blocking resources found. Safe to run terraform_startup.sh.${NC}"
  exit 0
fi
