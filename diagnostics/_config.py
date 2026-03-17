#!/usr/bin/env python3
"""Shared configuration and live-discovery helpers for LAB4 diagnostics.

All IDs are resolved at runtime:
  - tokyo_outputs() / gcp_outputs() read from LAB4-DELIVERABLES/ JSON files
    produced by terraform_startup.sh.
  - AWS resources (TGW route tables, VPC attachments, instances) are discovered
    via tag-based API calls using the TGW ID and VPC ID from those outputs.
  - gcloud / plink executables are found via PATH, GCLOUD_PATH env var, or
    common Windows install locations.
"""

import json
import os
import shutil
import subprocess
from pathlib import Path

# ─── Constants ────────────────────────────────────────────────────────────────
AWS_REGION   = "ap-northeast-1"
GCP_PROJECT  = "taaops"
GCP_VPC      = "nihonmachi-vpc01"
GCP_REGION   = "us-central1"
GCP_ROUTER   = "nihonmachi-cr01"
GCP_USER     = "jastek_sweeney"
GCP_INSTANCE_FILTER = "name~nihonmachi-app"

# ─── Deliverables path ────────────────────────────────────────────────────────
_LAB4_ROOT    = Path(__file__).resolve().parent.parent
_DELIVERABLES = _LAB4_ROOT / "LAB4-DELIVERABLES"


def _load_outputs(filename):
    """Return dict of key → value from a Terraform output JSON file."""
    path = _DELIVERABLES / filename
    if not path.exists():
        raise FileNotFoundError(
            f"Output file not found: {path}\n"
            "Run terraform_startup.sh first to generate LAB4-DELIVERABLES/."
        )
    raw = json.loads(path.read_text(encoding="utf-8"))
    return {k: v["value"] for k, v in raw.items()}


def tokyo_outputs():
    """Return dict of Tokyo stack Terraform outputs."""
    return _load_outputs("tokyo-outputs.json")


def gcp_outputs():
    """Return dict of newyork_gcp stack Terraform outputs."""
    return _load_outputs("newyork-gcp-outputs.json")


# ─── AWS helpers ──────────────────────────────────────────────────────────────
def aws(args, region=None):
    """Run an aws CLI command and return parsed JSON, or None on error."""
    env = {**os.environ, "AWS_DEFAULT_REGION": region or AWS_REGION}
    cmd = ["aws"] + args + ["--cli-connect-timeout", "5", "--cli-read-timeout", "30"]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=60, env=env)
    if r.returncode != 0:
        print(f"[aws error] {r.stderr[:400]}")
        return None
    try:
        return json.loads(r.stdout)
    except Exception:
        return r.stdout.strip() or None


def section(label):
    """Print a section header."""
    print(f"\n{'='*60}")
    print(f"  {label}")
    print(f"{'='*60}")


def print_json(data):
    """Pretty-print data."""
    if isinstance(data, (dict, list)):
        print(json.dumps(data, indent=2))
    else:
        print(data)


# ─── AWS resource discovery ───────────────────────────────────────────────────
def get_tgw_id():
    """Get Tokyo TGW ID from Terraform outputs."""
    return tokyo_outputs()["tokyo_transit_gateway_id"]


def get_vpc_id():
    """Get Tokyo VPC ID from Terraform outputs."""
    return tokyo_outputs()["tokyo_vpc_id"]


def get_gcp_ilb_ip():
    """Get GCP ILB IP from Terraform outputs."""
    return gcp_outputs()["nihonmachi_ilb_ip"]


def get_rds_endpoint():
    """Get Aurora cluster endpoint from Terraform outputs."""
    return tokyo_outputs()["database_endpoint"]


def get_tgw_route_tables(tgw_id):
    """Return list of {Id, Name, State} for all TGW route tables under tgw_id."""
    data = aws([
        "ec2", "describe-transit-gateway-route-tables", "--output", "json",
        "--filters", f"Name=transit-gateway-id,Values={tgw_id}",
        "--query", (
            "TransitGatewayRouteTables[*].{"
            "Id:TransitGatewayRouteTableId,"
            "State:State,"
            "Name:Tags[?Key=='Name']|[0].Value}"
        ),
    ])
    return data or []


def get_tgw_vpc_attachment(tgw_id, vpc_id):
    """Discover the TGW VPC attachment ID for this TGW + VPC pair."""
    data = aws([
        "ec2", "describe-transit-gateway-vpc-attachments", "--output", "json",
        "--filters",
        f"Name=transit-gateway-id,Values={tgw_id}",
        f"Name=vpc-id,Values={vpc_id}",
        "Name=state,Values=available,modifying,pending",
        "--query",
        "TransitGatewayVpcAttachments[0].{"
        "AttachId:TransitGatewayAttachmentId,"
        "State:State,"
        "SubnetIds:SubnetIds}",
    ])
    return data


def get_running_instances(vpc_id):
    """Return a flat list of running EC2 instances in the given VPC."""
    data = aws([
        "ec2", "describe-instances", "--output", "json",
        "--filters",
        f"Name=vpc-id,Values={vpc_id}",
        "Name=instance-state-name,Values=running",
        "--query", (
            "Reservations[*].Instances[*].{"
            "InstanceId:InstanceId,"
            "PrivateIp:PrivateIpAddress,"
            "SubnetId:SubnetId,"
            "Name:Tags[?Key=='Name']|[0].Value}"
        ),
    ])
    if not data:
        return []
    flat = []
    for group in data:
        if isinstance(group, list):
            flat.extend(group)
        else:
            flat.append(group)
    return flat


# ─── GCP helpers ──────────────────────────────────────────────────────────────
def find_gcloud():
    """Locate gcloud. Checks GCLOUD_PATH env var, PATH, then common Windows paths."""
    if "GCLOUD_PATH" in os.environ:
        return os.environ["GCLOUD_PATH"]
    found = shutil.which("gcloud") or shutil.which("gcloud.cmd")
    if found:
        return found
    candidates = [
        os.path.expandvars(
            r"%LOCALAPPDATA%\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd"
        ),
        os.path.expanduser(
            r"~\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd"
        ),
        r"C:\Program Files\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd",
    ]
    for p in candidates:
        if os.path.exists(p):
            return p
    raise RuntimeError(
        "gcloud not found. Add it to PATH or set GCLOUD_PATH=/path/to/gcloud."
    )


def find_plink():
    """Locate plink.exe (PuTTY SSH client) used by gcloud on Windows."""
    if "PLINK_PATH" in os.environ:
        return os.environ["PLINK_PATH"]
    gcmd = find_gcloud()
    gcloud_bin = Path(gcmd).parent
    candidates = [
        gcloud_bin / "sdk" / "plink.exe",
        gcloud_bin / "plink.exe",
        Path(os.path.expandvars(
            r"%LOCALAPPDATA%\Google\Cloud SDK\google-cloud-sdk\bin\sdk\plink.exe"
        )),
    ]
    for p in candidates:
        if p.exists():
            return str(p)
    found = shutil.which("plink")
    if found:
        return found
    raise RuntimeError(
        "plink.exe not found alongside gcloud SDK. "
        "Set PLINK_PATH=/path/to/plink.exe or install PuTTY."
    )


def _gcloud_env():
    env = os.environ.copy()
    py = shutil.which("python3") or shutil.which("python") or "python3"
    env["CLOUDSDK_PYTHON"] = py
    return env


def gcloud(args, label=None):
    """Run a gcloud command, print output. Returns subprocess.CompletedProcess."""
    gcmd = find_gcloud()
    if label:
        section(label)
    r = subprocess.run(
        [gcmd] + args,
        capture_output=True, text=True,
        env=_gcloud_env(), timeout=60,
    )
    if r.stdout.strip():
        print(r.stdout)
    if r.returncode != 0 and r.stderr.strip():
        print(f"STDERR: {r.stderr[:400]}")
    return r


def get_gcp_vm(zone_hint=GCP_REGION):
    """Discover first running nihonmachi-app VM. Returns (name, zone) or (None, None)."""
    gcmd = find_gcloud()
    r = subprocess.run(
        [gcmd, "compute", "instances", "list",
         f"--project={GCP_PROJECT}",
         f"--filter={GCP_INSTANCE_FILTER} AND status=RUNNING",
         "--format=value(name,zone)", "--limit=1"],
        capture_output=True, text=True,
        env=_gcloud_env(), timeout=30,
    )
    if r.returncode != 0 or not r.stdout.strip():
        return None, None
    parts = r.stdout.strip().split()
    name = parts[0]
    zone = parts[1].split("/")[-1] if len(parts) > 1 else f"{zone_hint}-b"
    return name, zone
