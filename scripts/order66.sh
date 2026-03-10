#!/usr/bin/env bash
# Break-glass CloudFront cache invalidation
#
# Usage:
#   bash scripts/order66.sh                              # invalidates /*
#   bash scripts/order66.sh "/static/placeholder.png"   # specific path
#   bash scripts/order66.sh "/images/*" "/api/*"        # multiple paths
#
# Run from LAB4 root. Reads the distribution ID from global Terraform state.
# Note: paths are CloudFront paths (e.g. /static/foo.png), not local filesystem paths.

# Disable Git Bash POSIX path conversion — CloudFront paths start with / and must not be expanded
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL="*"

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
  echo "    DIST_ID=EXXXXXXXXXX bash scripts/order66.sh"
  exit 1
fi

# Build paths array — default to /* if none provided
if [[ $# -gt 0 ]]; then
  PATHS=("$@")
else
  PATHS=("/*")
fi

QUANTITY=${#PATHS[@]}

CALLER_REF="break-glass-$(date +%s)"

echo ""
echo "=== Break-Glass CloudFront Invalidation ==="
echo "  Distribution : ${DIST_ID}"
echo "  Paths        : ${PATHS[*]}"
echo "  CallerRef    : ${CALLER_REF}"
echo ""
read -r -p "Confirm invalidation? This may incur cost. Type 'yes' to proceed: " confirm </dev/tty
[[ "$confirm" != "yes" ]] && echo "Cancelled." && exit 0

/c/Python311/python.exe - "${DIST_ID}" "${CALLER_REF}" "${PATHS[@]}" <<'PYEOF'
import sys, json, subprocess
dist_id   = sys.argv[1]
caller    = sys.argv[2]
paths     = sys.argv[3:]
batch     = json.dumps({"Paths": {"Quantity": len(paths), "Items": paths}, "CallerReference": caller})
tmp = "order66_tmp_batch.json"
open(tmp, "w").write(batch)
import os, pathlib
win_path = str(pathlib.Path(tmp).resolve())
result = subprocess.run(
    ["aws", "cloudfront", "create-invalidation",
     "--distribution-id", dist_id,
     "--invalidation-batch", f"file://{win_path}",
     "--query", "Invalidation.{Id:Id,Status:Status}",
     "--output", "table"],
    capture_output=False)
os.remove(tmp)
sys.exit(result.returncode)
PYEOF

echo ""
echo "Invalidation submitted. CloudFront typically propagates within 1-2 minutes."
