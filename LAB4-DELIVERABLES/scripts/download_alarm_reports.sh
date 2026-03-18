#!/usr/bin/env bash
set -euo pipefail

export AWS_PAGER=""
export AWS_CLI_AUTO_PROMPT="off"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TOKYO_OUTPUTS_JSON="$REPO_ROOT/LAB4-DELIVERABLES/tokyo-outputs.json"

# Downloads report files (json + md) flagged by alarm state.
# Requires: reports JSON files locally OR REPORT_BUCKET env to sync first.
#
# Usage:
#   REPORT_BUCKET=taaops-ir-reports-015195098145 ./scripts/download_alarm_reports.sh
#   REPORTS_DIR=./reports/IR ./scripts/download_alarm_reports.sh
#   ALARM_STATE=ALARM ./scripts/download_alarm_reports.sh
#   ALARM_NAME_REGEX="manual-test" ./scripts/download_alarm_reports.sh
#   ALARM_SINCE_EPOCH=1700000000 ./scripts/download_alarm_reports.sh
#   ALARM_SEVERITY=critical ./scripts/download_alarm_reports.sh

REPORTS_DIR="${REPORTS_DIR:-$REPO_ROOT/tests}"
REPORT_BUCKET="${REPORT_BUCKET:-}"
REGION="${REGION:-ap-northeast-1}"
ALARM_STATE="${ALARM_STATE:-ALARM}"
ALARM_NAME_REGEX="${ALARM_NAME_REGEX:-}"
ALARM_SINCE_EPOCH="${ALARM_SINCE_EPOCH:-}"
ALARM_UNTIL_EPOCH="${ALARM_UNTIL_EPOCH:-}"
ALARM_SEVERITY="${ALARM_SEVERITY:-}"
TRANSLATE_REPORTS="${TRANSLATE_REPORTS:-true}"
TRANSLATE_REGION="${TRANSLATE_REGION:-$REGION}"
TRANSLATION_INPUT_BUCKET="${TRANSLATION_INPUT_BUCKET:-}"
TRANSLATION_OUTPUT_BUCKET="${TRANSLATION_OUTPUT_BUCKET:-}"
TRANSLATED_DIR="${TRANSLATED_DIR:-$REPORTS_DIR/localized}"
PYTHON_BIN="${PYTHON_BIN:-}"
FORCE_S3_DOWNLOAD="${FORCE_S3_DOWNLOAD:-false}"

read_tokyo_output_json() {
  local key="$1"
  if [[ ! -f "$TOKYO_OUTPUTS_JSON" ]]; then
    return 1
  fi
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg k "$key" '.[$k].value // empty' "$TOKYO_OUTPUTS_JSON"
    return 0
  fi
  return 1
}

resolve_report_bucket() {
  if [[ -n "$REPORT_BUCKET" ]]; then
    return 0
  fi
  REPORT_BUCKET="$(read_tokyo_output_json incident_reports_bucket_name || true)"
  [[ -n "$REPORT_BUCKET" ]]
}

resolve_python() {
  if [[ -n "$PYTHON_BIN" ]]; then
    echo "$PYTHON_BIN"
    return 0
  fi
  if command -v /c/Python311/python.exe >/dev/null 2>&1; then
    echo "/c/Python311/python.exe"
    return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    echo "python3"
    return 0
  fi
  if command -v python >/dev/null 2>&1; then
    echo "python"
    return 0
  fi
  return 1
}

resolve_translation_buckets() {
  if [[ -n "$TRANSLATION_INPUT_BUCKET" && -n "$TRANSLATION_OUTPUT_BUCKET" ]]; then
    return 0
  fi
  if [[ -z "$TRANSLATION_INPUT_BUCKET" ]]; then
    TRANSLATION_INPUT_BUCKET="$(read_tokyo_output_json translation_input_bucket_name || true)"
  fi
  if [[ -z "$TRANSLATION_OUTPUT_BUCKET" ]]; then
    TRANSLATION_OUTPUT_BUCKET="$(read_tokyo_output_json translation_output_bucket_name || true)"
  fi
  if [[ -n "$TRANSLATION_INPUT_BUCKET" && -n "$TRANSLATION_OUTPUT_BUCKET" ]]; then
    return 0
  fi
  if ! command -v terraform >/dev/null 2>&1; then
    return 1
  fi

  local tokyo_dir
  tokyo_dir="$REPO_ROOT/Tokyo"
  if [[ ! -d "$tokyo_dir" ]]; then
    return 1
  fi

  if [[ -z "$TRANSLATION_INPUT_BUCKET" ]]; then
    TRANSLATION_INPUT_BUCKET="$(terraform -chdir="$tokyo_dir" output -raw translation_input_bucket_name 2>/dev/null || true)"
  fi
  if [[ -z "$TRANSLATION_OUTPUT_BUCKET" ]]; then
    TRANSLATION_OUTPUT_BUCKET="$(terraform -chdir="$tokyo_dir" output -raw translation_output_bucket_name 2>/dev/null || true)"
  fi

  [[ -n "$TRANSLATION_INPUT_BUCKET" && -n "$TRANSLATION_OUTPUT_BUCKET" ]]
}

resolve_report_bucket || true

if [[ -n "$REPORT_BUCKET" ]]; then
  mkdir -p "$REPORTS_DIR"
  aws s3 sync "s3://$REPORT_BUCKET/reports/" "$REPORTS_DIR/" \
    --exclude "*" --include "*.json" --region "$REGION" >/dev/null
fi

if [[ ! -d "$REPORTS_DIR" ]]; then
  echo "ERROR: reports directory not found: $REPORTS_DIR"
  exit 1
fi

shopt -s nullglob
json_files=("$REPORTS_DIR"/*.json)
if [[ ${#json_files[@]} -eq 0 ]]; then
  echo "No report JSON files found in $REPORTS_DIR"
  exit 0
fi

match_files=()
if command -v jq >/dev/null 2>&1; then
  for f in "${json_files[@]}"; do
    if jq -e --arg state "$ALARM_STATE" \
      --arg name_re "$ALARM_NAME_REGEX" \
      --argjson since_epoch "${ALARM_SINCE_EPOCH:-null}" \
      --argjson until_epoch "${ALARM_UNTIL_EPOCH:-null}" \
      --arg severity "$ALARM_SEVERITY" \
      '
      def tstamp:
        (.alarm.StateChangeTime // .generated_at // "");
      def time_ok:
        if ($since_epoch == null and $until_epoch == null) then true
        else
          (tstamp | fromdateiso8601) as $ts |
          (if $since_epoch == null then true else $ts >= $since_epoch end) and
          (if $until_epoch == null then true else $ts <= $until_epoch end)
        end;
      def name_ok:
        if $name_re == "" then true
        else (.alarm.AlarmName // "") | test($name_re)
        end;
      def severity_ok:
        if $severity == "" then true
        else
          ((.alarm.Severity // .alarm.severity // "") | ascii_downcase) == ($severity | ascii_downcase) or
          ((.alarm.AlarmDescription // "") | test("(?i)severity[:= ]*" + $severity))
        end;
      (.alarm.NewStateValue==$state) and name_ok and time_ok and severity_ok
      ' "$f" >/dev/null 2>&1; then
      match_files+=("$f")
    fi
  done
else
  if [[ -n "$ALARM_NAME_REGEX" || -n "$ALARM_SINCE_EPOCH" || -n "$ALARM_UNTIL_EPOCH" || -n "$ALARM_SEVERITY" ]]; then
    echo "WARN: jq not found; name/time/severity filters require jq. Falling back to state only."
  fi
  while IFS= read -r line; do
    match_files+=("$line")
  done < <(grep -l "\"NewStateValue\": \"$ALARM_STATE\"" "${json_files[@]}" || true)
fi

if [[ ${#match_files[@]} -eq 0 ]]; then
  echo "No ${ALARM_STATE} reports found in $REPORTS_DIR"
  exit 0
fi

if [[ -z "$REPORT_BUCKET" ]]; then
  echo "${ALARM_STATE} reports (local):"
  printf '%s\n' "${match_files[@]}"
  if [[ "$TRANSLATE_REPORTS" != "true" ]]; then
    exit 0
  fi
fi

if [[ -n "$REPORT_BUCKET" ]]; then
  echo "Downloading matching report pairs..."
  for f in "${match_files[@]}"; do
    base="$(basename "$f" .json)"
    if [[ "$FORCE_S3_DOWNLOAD" != "true" && -f "$REPORTS_DIR/${base}.json" && -f "$REPORTS_DIR/${base}.md" ]]; then
      continue
    fi
    if ! aws s3 cp "s3://$REPORT_BUCKET/reports/${base}.json" "$REPORTS_DIR/${base}.json" --region "$REGION"; then
      echo "WARN: could not download reports/${base}.json from s3://$REPORT_BUCKET (using local copy if present)"
    fi
    if ! aws s3 cp "s3://$REPORT_BUCKET/reports/${base}.md" "$REPORTS_DIR/${base}.md" --region "$REGION"; then
      echo "WARN: could not download reports/${base}.md from s3://$REPORT_BUCKET (using local copy if present)"
    fi
  done
fi

if [[ "$TRANSLATE_REPORTS" != "true" ]]; then
  echo "Translation skipped (TRANSLATE_REPORTS=$TRANSLATE_REPORTS)."
  exit 0
fi

if ! resolve_translation_buckets; then
  echo "ERROR: could not resolve translation buckets. Set TRANSLATION_INPUT_BUCKET and TRANSLATION_OUTPUT_BUCKET."
  exit 1
fi

py_cmd="$(resolve_python || true)"
if [[ -z "$py_cmd" ]]; then
  echo "ERROR: Python interpreter not found. Set PYTHON_BIN or install python3."
  exit 1
fi

mkdir -p "$TRANSLATED_DIR"
echo "Translating markdown reports to Japanese into $TRANSLATED_DIR ..."
for f in "${match_files[@]}"; do
  base="$(basename "$f" .json)"
  md_file="$REPORTS_DIR/${base}.md"
  if [[ ! -f "$md_file" ]]; then
    echo "WARN: markdown not found for $base, skipping translation"
    continue
  fi
  "$py_cmd" "$REPO_ROOT/python/translate_via_s3.py" \
    --input-bucket "$TRANSLATION_INPUT_BUCKET" \
    --output-bucket "$TRANSLATION_OUTPUT_BUCKET" \
    --source-file "$md_file" \
    --region "$TRANSLATE_REGION" \
    --s3-key "tests/${base}.md" \
    --download-to "$TRANSLATED_DIR/${base}-jpn.md"
done

echo "Done. Downloaded and translated reports are in: $REPORTS_DIR"
