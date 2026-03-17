#!/usr/bin/env python3
# translate_batch_audit.py
# Galactus speaks multiple languages. 
# This translates log files from the Tokyo audit to Japanese via the S3-triggered Lambda translation pipeline:
# Batch-translates all files matching a glob pattern in a local source directory # (default: LAB4-DELIVERABLES/*.md)
# to Japanese via the S3-triggered Lambda translation pipeline. 
#
# For each file it:
# Uploads each file to the input bucket,
# waits for the Lambda to write the translated object to the output bucket, 
# downloads it to LAB4-DELIVERABLES/localized/ with a -jpn suffix.
# Structured JSON files are skipped by default to avoid invalid JSON output.
# It delegates per-file work to translate_via_s3.py.
# Usage: see DEPLOYMENT_GUIDE.md or run with --help

import argparse
import subprocess
import sys
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
DEFAULT_SOURCE_DIR = REPO_ROOT / "LAB4-DELIVERABLES"
DEFAULT_DEST_DIR = REPO_ROOT / "LAB4-DELIVERABLES" / "localized"


def parse_args():
    p = argparse.ArgumentParser(
        description="Batch-translate files from a local directory via S3 input/output buckets."
    )
    p.add_argument("--input-bucket", required=True)
    p.add_argument("--output-bucket", required=True)
    p.add_argument("--source-dir", default=str(DEFAULT_SOURCE_DIR), help="Local folder of source files.")
    p.add_argument(
        "--glob",
        default="*.md",
        help="File pattern in source dir. Prefer text/markdown (for example: *.md, *.txt).",
    )
    p.add_argument("--region", default=None)
    p.add_argument("--timeout-seconds", type=int, default=180)
    p.add_argument("--poll-seconds", type=int, default=5)
    p.add_argument("--key-prefix", default="lab4-deliverables", help="S3 input key prefix.")
    p.add_argument(
        "--dest-dir",
        default=str(DEFAULT_DEST_DIR),
        help="Local folder for downloaded translated files.",
    )
    p.add_argument(
        "--allow-structured-json",
        action="store_true",
        help=(
            "Allow translating .json files as documents. Not recommended because document translation "
            "can change punctuation/quotes and produce invalid JSON."
        ),
    )
    p.add_argument(
        "--safe-json",
        action="store_true",
        help="Translate .json using structure-aware mode (preserves valid JSON).",
    )
    p.add_argument(
        "--json-translate-keys",
        action="store_true",
        help="When --safe-json is enabled, translate JSON object keys as well as values.",
    )
    return p.parse_args()


def main():
    args = parse_args()
    if args.glob.lower().endswith(".json") and not args.allow_structured_json:
        args.safe_json = True

    src_dir = Path(args.source_dir)
    files = sorted(src_dir.glob(args.glob))
    if not files:
        print(f"[ERROR] No files found: {src_dir}/{args.glob}", file=sys.stderr)
        return 2

    dest_dir = Path(args.dest_dir)
    dest_dir.mkdir(parents=True, exist_ok=True)

    failures = 0
    skipped = 0
    processed = 0
    for f in files:
        if f.suffix.lower() == ".json":
            if args.safe_json:
                out_file = dest_dir / f"{f.stem}-jpn{f.suffix or '.json'}"
                cmd = [
                    sys.executable,
                    str(Path(__file__).with_name("translate_json_safe.py")),
                    "--source-file",
                    str(f),
                    "--download-to",
                    str(out_file),
                ]
                if args.region:
                    cmd.extend(["--region", args.region])
                if args.json_translate_keys:
                    cmd.append("--translate-keys")

                print(f"[INFO] Processing JSON safely {f}")
                rc = subprocess.call(cmd)
                processed += 1
                if rc != 0:
                    failures += 1
                    print(f"[ERROR] Failed: {f}")
                continue

            if not args.allow_structured_json:
                skipped += 1
                print(
                    f"[WARN] Skipping structured JSON (unsafe for document translation): {f}. "
                    "Use --safe-json (recommended) or --allow-structured-json (unsafe) to process it."
                )
                continue

        s3_key = f"{args.key_prefix}/{f.name}"
        out_file = dest_dir / f"{f.stem}-jpn{f.suffix or '.txt'}"
        cmd = [
            sys.executable,
            str(Path(__file__).with_name("translate_via_s3.py")),
            "--input-bucket",
            args.input_bucket,
            "--output-bucket",
            args.output_bucket,
            "--source-file",
            str(f),
            "--s3-key",
            s3_key,
            "--timeout-seconds",
            str(args.timeout_seconds),
            "--poll-seconds",
            str(args.poll_seconds),
            "--download-to",
            str(out_file),
        ]
        if args.region:
            cmd.extend(["--region", args.region])

        print(f"[INFO] Processing {f}")
        rc = subprocess.call(cmd)
        processed += 1
        if rc != 0:
            failures += 1
            print(f"[ERROR] Failed: {f}")

    if processed == 0 and skipped > 0:
        print("[DONE] No files processed. JSON files were skipped for safety.")
        return 0

    if failures:
        print(f"[DONE] Completed with {failures} failure(s).", file=sys.stderr)
        return 1
    print("[DONE] All files translated successfully.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
