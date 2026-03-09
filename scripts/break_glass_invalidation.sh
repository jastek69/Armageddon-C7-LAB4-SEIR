#!/usr/bin/env bash
# Break-glass CloudFront cache invalidation
#
# Usage:
#   bash scripts/break_glass_invalidation.sh                        # invalidates /*
#   bash scripts/break_glass_invalidation.sh "/images/*" "/api/*"   # specific paths
#
# Run from LAB4 root. Reads the distribution ID from global Terraform state.

set -euo pipefail

REGION="ap-northeast-1"
STATE_BUCKET="taaops-terraform-state-tokyo"
STATE_KEY="global/global022126terraform.tfstate"

# Resolve distribution ID from remote state (no manual config needed)
echo "Fetching CloudFront distribution ID from Terraform state..."
DIST_ID=$(aws s3 cp "s3://${STATE_BUCKET}/${STATE_KEY}" - --region "${REGION}" 2>/dev/null \
  | /c/Python311/python.exe -c "import sys,json; s=json.load(sys.stdin); print(next(v['value'] for r in s['resources'] if r.get('type')=='aws_cloudfront_distribution' for inst in r['instances'] for v in [inst['attributes']] if True), None) or print([o['value'] for o in s.get('outputs',{}).values() if 'cloudfront_distribution_id' in str(o)][0])" 2>/dev/null \
  || true)

# Fallback: read from outputs file
if [[ -z "${DIST_ID:-}" && -f "LAB4-DELIVERABLES/global-outputs.json" ]]; then
  DIST_ID=$(/c/Python311/python.exe -c "import json; print(json.load(open('LAB4-DELIVERABLES/global-outputs.json'))['cloudfront_distribution_id']['value'])" 2>/dev/null || true)
fi

if [[ -z "${DIST_ID:-}" ]]; then
  echo "ERROR: Could not resolve CloudFront distribution ID."
  echo "  Option 1: Run 'cd global && terraform output cloudfront_distribution_id' and pass it manually:"
  echo "    DIST_ID=EXXXXXXXXXX bash scripts/break_glass_invalidation.sh"
  exit 1
fi

# Build paths array — default to /* if none provided
if [[ $# -gt 0 ]]; then
  PATHS=("$@")
else
  PATHS=("/*")
fi

QUANTITY=${#PATHS[@]}
ITEMS_JSON=$(python3 -c "import json,sys; print(json.dumps(sys.argv[1:]))" -- "${PATHS[@]}" 2>/dev/null \
  || /c/Python311/python.exe -c "import json,sys; print(json.dumps(sys.argv[1:]))" -- "${PATHS[@]}")

CALLER_REF="break-glass-$(date +%s)"

echo ""
echo "=== Break-Glass CloudFront Invalidation ==="
echo "  Distribution : ${DIST_ID}"
echo "  Paths        : ${PATHS[*]}"
echo "  CallerRef    : ${CALLER_REF}"
echo ""
read -r -p "Confirm invalidation? This may incur cost. Type 'yes' to proceed: " confirm </dev/tty
[[ "$confirm" != "yes" ]] && echo "Cancelled." && exit 0

aws cloudfront create-invalidation \
  --distribution-id "${DIST_ID}" \
  --region us-east-1 \
  --invalidation-batch "{
    \"Paths\": { \"Quantity\": ${QUANTITY}, \"Items\": ${ITEMS_JSON} },
    \"CallerReference\": \"${CALLER_REF}\"
  }" \
  --query "Invalidation.{Id:Id,Status:Status}" \
  --output table

echo ""
echo "Invalidation submitted. CloudFront typically propagates within 1-2 minutes."
