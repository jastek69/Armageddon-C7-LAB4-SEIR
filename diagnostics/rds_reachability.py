#!/usr/bin/env python3
"""
RDS Reachability — run rds_test.py on a GCP VM over IAP tunnel + plink.

Discovers:
  - Running nihonmachi-app VM name + zone via gcloud
  - plink.exe alongside the gcloud SDK

The test runs /usr/local/bin/rds_test.py on the GCP VM which connects back
to the Aurora cluster in Tokyo over the VPN corridor.

Expected output:
    {"status": "ok", "latest_ts": "2026-..."}

Usage:
    python diagnostics/rds_reachability.py
    python diagnostics/rds_reachability.py --instance nihonmachi-app-r65k --zone us-central1-b
"""

import argparse
import os
import subprocess
import sys
import threading
import time
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))

from _config import (
    find_gcloud, find_plink, _gcloud_env,
    get_gcp_vm, GCP_PROJECT, GCP_USER,
)

REMOTE_CMD = (
    "source /etc/profile.d/tokyo_rds.sh 2>/dev/null; "
    "python3 /usr/local/bin/rds_test.py"
)
IAP_PORT = 2256


def run_rds_test(vm_name, vm_zone):
    gcmd   = find_gcloud()
    plink  = find_plink()
    key    = os.path.expanduser("~/.ssh/google_compute_engine.ppk")
    env    = _gcloud_env()

    print(f"VM     : {vm_name} ({vm_zone})")
    print(f"gcloud : {gcmd}")
    print(f"plink  : {plink}")
    print(f"key    : {key}")
    print(f"IAP port: {IAP_PORT}")

    # Start IAP tunnel
    print(f"\nStep 1 — Starting IAP tunnel on localhost:{IAP_PORT}...")
    iap_proc = subprocess.Popen(
        [gcmd, "compute", "start-iap-tunnel", vm_name, "22",
         f"--zone={vm_zone}",
         f"--project={GCP_PROJECT}",
         f"--local-host-port=localhost:{IAP_PORT}",
         "--verbosity=info"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env,
    )

    ready_event = threading.Event()

    def watch_iap_stderr():
        for raw in iap_proc.stderr:
            line = raw.decode("utf-8", errors="replace").strip()
            if "Listening on port" in line or "listening on port" in line.lower():
                print(f"  IAP ready: {line}")
                ready_event.set()

    t = threading.Thread(target=watch_iap_stderr, daemon=True)
    t.start()

    if not ready_event.wait(timeout=30):
        print("  IAP tunnel did not signal ready within 30s, proceeding anyway...")

    print("\nStep 2 — Running rds_test.py via plink...")
    try:
        result = subprocess.run(
            [plink,
             "-ssh", f"{GCP_USER}@localhost",
             "-P", str(IAP_PORT),
             "-i", key,
             "-batch",            # Non-interactive, reject unknown host keys
             "-no-antispoof",
             REMOTE_CMD],
            capture_output=True, text=True,
            timeout=60, env=env,
        )
        if result.stdout.strip():
            print("\nResult:")
            print(result.stdout.strip())
        if result.stderr.strip():
            print(f"\nSTDERR: {result.stderr[:500]}")
        if result.returncode != 0:
            print(f"\nplink exited {result.returncode}")
    finally:
        iap_proc.terminate()
        try:
            iap_proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            iap_proc.kill()
        print("\nIAP tunnel closed.")


def main():
    parser = argparse.ArgumentParser(description="Run rds_test.py on GCP VM via IAP")
    parser.add_argument("--instance", help="GCP VM name (auto-discovered if omitted)")
    parser.add_argument("--zone", help="GCP zone (auto-discovered if omitted)")
    args = parser.parse_args()

    if args.instance:
        vm_name = args.instance
        vm_zone = args.zone or "us-central1-b"
    else:
        vm_name, vm_zone = get_gcp_vm()
        if not vm_name:
            print("No running nihonmachi-app instance found. Is the stack deployed?")
            sys.exit(1)

    run_rds_test(vm_name, vm_zone)


if __name__ == "__main__":
    main()
