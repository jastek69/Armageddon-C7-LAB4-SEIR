#!/usr/bin/env bash
# LAB4 multi-stack Terraform deployment
# Order: GCP seed -> Tokyo -> Global -> New York GCP -> Sao Paulo
# Maintainer note: active stacks are in `Tokyo/`, `global/`, `newyork_gcp/`, `saopaulo/`; legacy root Terraform files are in `archive/root-terraform-from-root/`.
# To Run:
#   1. From LAB4 root: source .secrets.env
#   2. From LAB4 root: bash terraform_startup.sh
###############################################################################################################

set -euo pipefail
trap 'echo "ERROR on line $LINENO"; exit 1' ERR

WAIT_TIME=30
TGW_WAIT_TIME=120
DELIVERABLES_DIR="LAB4-DELIVERABLES"

run_apply() {
  local stack_dir="$1"
  local plan_file="$2"
  echo ""
  echo "=== Deploying ${stack_dir} ==="
  cd "$stack_dir"
  terraform init -upgrade
  terraform validate
  terraform plan -out="$plan_file"
  terraform apply -auto-approve "$plan_file"
  cd - >/dev/null
}

run_apply_targets() {
  local stack_dir="$1"
  local plan_file="$2"
  shift 2
  local targets=("$@")
  echo ""
  echo "=== Deploying ${stack_dir} (targeted) ==="
  cd "$stack_dir"
  terraform init -upgrade
  terraform validate
  terraform plan -out="$plan_file" "${targets[@]/#/-target=}"
  terraform apply -auto-approve "$plan_file"
  cd - >/dev/null
}



dump_outputs() {
  local stack_dir="$1"
  local out_file="$2"
  echo ""
  echo "=== Capturing Terraform outputs for ${stack_dir} ==="
  mkdir -p "$DELIVERABLES_DIR"
  cd "$stack_dir"
  terraform output -json > "../${DELIVERABLES_DIR}/${out_file}"
  cd - >/dev/null
}

assert_tokyo_state() {
  echo ""
  echo "=== Verifying Tokyo state exists before deploying dependent stacks ==="
  cd Tokyo
  if terraform output -json >/dev/null 2>&1; then
    echo "  Tokyo state verified — proceeding to dependent stacks."
  else
    echo ""
    echo "ERROR: Tokyo state not found or empty."
    echo "  Tokyo apply may have failed or state was not written to S3."
    echo "  Fix the Tokyo stack error above, then rerun terraform_startup.sh."
    echo "  Dependent stacks (global, newyork_gcp, saopaulo) will be skipped."
    exit 1
  fi
  cd - >/dev/null
}

# Validate required secret env vars are set (must source .secrets.env first)
REQUIRED_VARS=(TF_VAR_db_password TF_VAR_psk_tunnel_1 TF_VAR_psk_tunnel_2 TF_VAR_psk_tunnel_3 TF_VAR_psk_tunnel_4)
MISSING=()
for v in "${REQUIRED_VARS[@]}"; do
  [[ -z "${!v:-}" ]] && MISSING+=("$v")
done
if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "ERROR: Required environment variables are not set:"
  printf '  %s\n' "${MISSING[@]}"
  echo "Run: source .secrets.env   (from LAB4 root)"
  exit 1
fi

echo "Starting LAB4 deployment: GCP seed -> Tokyo -> Global -> New York GCP -> Sao Paulo"

# Stage -3: Force-delete any secrets pending deletion (7-day recovery window blocks recreate)
echo ""
echo "=== Clearing secrets pending deletion ==="
for secret_region in "taaops/rds/mysql:ap-northeast-1" "nihonmachi-tokyo-rds-password:us-central1"; do
  secret="${secret_region%%:*}"
  region="${secret_region##*:}"
  # Only delete if secret exists and is pending deletion
  status=$(aws secretsmanager describe-secret --secret-id "$secret" --region "$region" \
    --query 'DeletedDate' --output text 2>/dev/null || echo "None")
  if [[ "$status" != "None" && "$status" != "" ]]; then
    echo "  Force-deleting pending secret: $secret"
    aws secretsmanager delete-secret --secret-id "$secret" \
      --force-delete-without-recovery --region "$region" 2>/dev/null || true
  else
    echo "  Secret $secret: not pending deletion"
  fi
done

# Stage -2: Ensure S3 state buckets exist (prerequisite for backend init)
echo ""
echo "=== Ensuring S3 state buckets exist ==="
for bucket_region in "taaops-terraform-state-tokyo:ap-northeast-1" "taaops-terraform-state-saopaulo:sa-east-1"; do
  bucket="${bucket_region%%:*}"
  region="${bucket_region##*:}"
  if aws s3api head-bucket --bucket "$bucket" --region "$region" 2>/dev/null; then
    echo "  S3 bucket $bucket already exists"
  else
    echo "  Creating S3 bucket $bucket in $region..."
    if [[ "$region" == "us-east-1" ]]; then
      aws s3api create-bucket --bucket "$bucket" --region "$region"
    else
      aws s3api create-bucket --bucket "$bucket" --region "$region" \
        --create-bucket-configuration LocationConstraint="$region"
    fi
    aws s3api put-bucket-versioning --bucket "$bucket" --region "$region" \
      --versioning-configuration Status=Enabled
    aws s3api put-bucket-encryption --bucket "$bucket" --region "$region" \
      --server-side-encryption-configuration \
      '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
    echo "  Created $bucket"
  fi
done

# Stage -1: Import any orphaned CloudWatch log groups that survived a partial destroy.
# Scenario: destroy was interrupted after Terraform removed the resource from state
# but before it deleted it from AWS. Next apply would hit ResourceAlreadyExistsException.
# Note: MSYS_NO_PATHCONV=1 is required — Git Bash converts /vpc/... to a Windows path otherwise.
# Note: Use -chdir= instead of a subshell (cd Tokyo; ...) — on Windows/Git Bash, native .exe
#       binaries do not inherit the subshell's cwd, so terraform still sees the parent directory.
echo ""
echo "=== Pre-flight: checking for orphaned log groups ==="
terraform -chdir=Tokyo init -upgrade -no-color > /dev/null 2>&1 || true

orphaned_log_groups=(
  "aws_cloudwatch_log_group.tokyo_rds_flowlogs:/vpc/flowlogs/tokyo-rds:ap-northeast-1"
)
for entry in "${orphaned_log_groups[@]}"; do
  resource="${entry%%:*}"; rest="${entry#*:}"; log_group="${rest%%:*}"; region="${rest##*:}"
  exists=$(MSYS_NO_PATHCONV=1 aws logs describe-log-groups \
    --log-group-name-prefix "$log_group" \
    --region "$region" \
    --query "logGroups[?logGroupName=='${log_group}'].logGroupName" \
    --output text 2>/dev/null || true)
  if [[ -n "$exists" ]]; then
    if terraform -chdir=Tokyo state list 2>/dev/null | grep -q "^${resource}$"; then
      echo "  $log_group — in state, skipping."
    else
      echo "  $log_group — exists in AWS but not in state; importing..."
      MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*" \
        terraform -chdir=Tokyo import "$resource" "$log_group"
      echo "  Import complete."
    fi
  else
    echo "  $log_group — not in AWS (fresh deploy), skipping."
  fi
done

# Stage 0: GCP seed (HA VPN public IPs)
run_apply_targets "newyork_gcp" "gcp-seed.tfplan" \
  "google_compute_network.nihonmachi-vpc" \
  "google_compute_ha_vpn_gateway.gcp-to-aws-vpn-gw"
echo "Waiting ${WAIT_TIME}s for GCP HA VPN to stabilize..."
sleep "$WAIT_TIME"

# Stage 1: Tokyo
run_apply "Tokyo" "tokyo.tfplan"
echo "Waiting ${WAIT_TIME}s for Tokyo resources to stabilize..."
sleep "$WAIT_TIME"
assert_tokyo_state

# Stage 2: Global
run_apply "global" "global.tfplan"
echo "Waiting ${WAIT_TIME}s for Global resources to stabilize..."
sleep "$WAIT_TIME"

# Stage 3: New York GCP (full)
# Note: 5-gcp-vpn-connections.tf contains a time_sleep.wait_for_vpn_tunnels
# resource (90s) that gates interface/peer creation until tunnels are ESTABLISHED,
# preventing the nextHopOrigin=INCOMPLETE Cloud Router race condition.
run_apply "newyork_gcp" "newyork-gcp.tfplan"

# Stage 4: Sao Paulo
run_apply "saopaulo" "saopaulo.tfplan"
echo "Waiting ${TGW_WAIT_TIME}s for TGW peering/resources to stabilize..."
sleep "$TGW_WAIT_TIME"

# Stage 4b: Capture outputs for deliverables
dump_outputs "Tokyo" "tokyo-outputs.json"
dump_outputs "global" "global-outputs.json"
dump_outputs "newyork_gcp" "newyork-gcp-outputs.json"
dump_outputs "saopaulo" "saopaulo-outputs.json"

# Stage 4: Summary outputs
echo ""
echo "=== Deployment summary ==="

cd Tokyo
TOKYO_TGW_ID=$(terraform output -raw tokyo_transit_gateway_id 2>/dev/null || echo "Not found")
TOKYO_ALB_DNS=$(terraform output -raw tokyo_alb_dns_name 2>/dev/null || echo "Not found")
cd - >/dev/null

cd global
CF_DIST_ID=$(terraform output -raw cloudfront_distribution_id 2>/dev/null || echo "Not found")
CF_DIST_DOMAIN=$(terraform output -raw cloudfront_distribution_domain_name 2>/dev/null || echo "Not found")
ORIGIN_FQDN=$(terraform output -raw origin_fqdn 2>/dev/null || echo "Not found")
cd - >/dev/null

cd saopaulo
SAO_TGW_ID=$(terraform output -raw saopaulo_transit_gateway_id 2>/dev/null || echo "Not found")
SAO_ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "Not found")
cd - >/dev/null

echo "Tokyo TGW:             $TOKYO_TGW_ID"
echo "Tokyo ALB:             $TOKYO_ALB_DNS"
echo "Global CloudFront ID:  $CF_DIST_ID"
echo "Global CloudFront DNS: $CF_DIST_DOMAIN"
echo "Global Origin FQDN:    $ORIGIN_FQDN"
echo "Sao Paulo TGW:         $SAO_TGW_ID"
echo "Sao Paulo ALB:         $SAO_ALB_DNS"

if [[ "$TOKYO_TGW_ID" != "Not found" && "$CF_DIST_ID" != "Not found" && "$SAO_TGW_ID" != "Not found" ]]; then
  echo ""
  echo "LAB4 deployment complete."
else
  echo ""
  echo "Deployment finished with missing outputs. Review stack logs above."
  exit 1
fi
