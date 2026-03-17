#!/usr/bin/env bash
set -euo pipefail

export AWS_PAGER=""
export AWS_CLI_AUTO_PROMPT="off"

# Usage:
#   ./scripts/publish_sanity_check.sh
#   ./scripts/publish_sanity_check.sh s3://my-bucket/tools/sanity_check.sh
#   ./scripts/publish_sanity_check.sh s3://my-bucket/tools/sanity_check.sh 3600

S3_URI="${1:-}"
EXPIRES_IN="${2:-3600}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_PATH="$ROOT_DIR/sanity_check.sh"
REGION="${REGION:-ap-northeast-1}"

if [[ -z "$S3_URI" ]]; then
  if command -v terraform >/dev/null 2>&1 && [[ -d "$ROOT_DIR/Tokyo" ]]; then
    report_bucket="$(terraform -chdir="$ROOT_DIR/Tokyo" output -raw incident_reports_bucket_name 2>/dev/null || true)"
    if [[ -n "$report_bucket" && "$report_bucket" != "None" ]]; then
      S3_URI="s3://$report_bucket/tools/sanity_check.sh"
      echo "Auto-resolved publish target: $S3_URI"
    fi
  fi
fi

if [[ -z "$S3_URI" ]]; then
  echo "Usage: $0 [s3://bucket/path/to/sanity_check.sh] [expires_in_seconds]"
  echo "ERROR: Could not auto-resolve S3 URI. Provide one explicitly."
  exit 1
fi

if [[ ! -f "$SCRIPT_PATH" ]]; then
  echo "ERROR: sanity_check.sh not found at $SCRIPT_PATH"
  exit 1
fi

echo "Uploading $SCRIPT_PATH to $S3_URI ..."
aws s3 cp "$SCRIPT_PATH" "$S3_URI" --region "$REGION"

echo "Generating pre-signed URL (expires in ${EXPIRES_IN}s) ..."
aws s3 presign "$S3_URI" --expires-in "$EXPIRES_IN" --region "$REGION"
