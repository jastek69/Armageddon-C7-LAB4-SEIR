#!/usr/bin/env python3
"""Translate JSON safely by preserving structure and translating text fields only.

This avoids document-level JSON corruption caused by punctuation/quote rewriting.
"""

import argparse
import json
import re
import sys
from pathlib import Path

import boto3
from botocore.exceptions import ClientError


SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent


def parse_args():
    p = argparse.ArgumentParser(description="Structure-aware JSON translation.")
    p.add_argument("--source-file", required=True, help="Input JSON file path.")
    p.add_argument("--download-to", default=None, help="Output JSON path.")
    p.add_argument("--region", default=None, help="AWS region.")
    p.add_argument("--source-lang", default="auto", help="Source language code (default: auto).")
    p.add_argument("--target-lang", default="ja", help="Target language code (default: ja).")
    p.add_argument(
        "--translate-keys",
        action="store_true",
        help="Translate dictionary keys in addition to values.",
    )
    return p.parse_args()


def default_output_path(src: Path) -> Path:
    return REPO_ROOT / "LAB4-DELIVERABLES" / "localized" / f"{src.stem}-jpn{src.suffix or '.json'}"


def looks_machine_value(text: str) -> bool:
    t = text.strip()
    if not t:
        return True
    patterns = [
        r"^arn:aws:",
        r"^[a-z]+-[a-z0-9-]+-\d+$",  # region-ish
        r"^\d+\.\d+\.\d+\.\d+(/\d+)?$",  # IPv4/CIDR
        r"^[A-Z0-9]{8,}$",  # ids/tokens
        r"^[a-z0-9][a-z0-9.-]*\.[a-z]{2,}$",  # domain-like
        r"^[a-z]+://",
        r"^vpce?-",
        r"^sg-",
        r"^subnet-",
        r"^vpc-",
        r"^tgw-",
    ]
    return any(re.match(p, t, flags=re.IGNORECASE) for p in patterns)


def translate_text(client, text: str, source_lang: str, target_lang: str) -> str:
    if looks_machine_value(text):
        return text
    if len(text.strip()) < 2:
        return text
    resp = client.translate_text(
        Text=text,
        SourceLanguageCode=source_lang,
        TargetLanguageCode=target_lang,
    )
    return resp.get("TranslatedText", text)


def translate_obj(obj, client, source_lang: str, target_lang: str, translate_keys: bool):
    if isinstance(obj, dict):
        out = {}
        for k, v in obj.items():
            new_key = translate_text(client, k, source_lang, target_lang) if translate_keys else k
            out[new_key] = translate_obj(v, client, source_lang, target_lang, translate_keys)
        return out
    if isinstance(obj, list):
        return [translate_obj(x, client, source_lang, target_lang, translate_keys) for x in obj]
    if isinstance(obj, str):
        return translate_text(client, obj, source_lang, target_lang)
    return obj


def main():
    args = parse_args()
    src = Path(args.source_file)
    if not src.exists():
        print(f"[ERROR] Source file not found: {src}", file=sys.stderr)
        return 2

    try:
        payload = json.loads(src.read_text(encoding="utf-8"))
    except Exception as exc:
        print(f"[ERROR] Invalid JSON: {src} ({exc})", file=sys.stderr)
        return 2

    session = boto3.session.Session(region_name=args.region) if args.region else boto3.session.Session()
    client = session.client("translate")

    translated = translate_obj(payload, client, args.source_lang, args.target_lang, args.translate_keys)
    out_path = Path(args.download_to) if args.download_to else default_output_path(src)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(translated, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(f"[OK] Safe JSON translation complete: {out_path}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ClientError as exc:
        print(f"[ERROR] AWS error: {exc}", file=sys.stderr)
        raise SystemExit(1)
