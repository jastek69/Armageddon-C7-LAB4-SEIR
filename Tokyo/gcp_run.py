#!/usr/bin/env python3
"""Run a command on GCP VM via IAP tunnel + plink, capturing output."""

import subprocess
import sys
import time
import threading
import os

ZONE = "us-central1-b"
PROJECT = "taaops"
INSTANCE = "nihonmachi-app-r65k"
USER = "jastek_sweeney"
KEY = os.path.expanduser("~/.ssh/google_compute_engine.ppk")
PLINK = r"C:\Users\John Sweeney\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin\sdk\plink.exe"
GCLOUD = r"C:\Users\John Sweeney\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin\gcloud"

REMOTE_COMMAND = "source /etc/profile.d/tokyo_rds.sh && python3 /usr/local/bin/rds_test.py"

# Build IAP tunnel command to get the proxy command string
# Use gcloud to get the tunnel info
import shlex

# Start IAP tunnel process for port 22
iap_port = 2229
iap_cmd = [
    GCLOUD, "compute", "start-iap-tunnel", INSTANCE, "22",
    f"--zone={ZONE}", f"--project={PROJECT}",
    f"--local-host-port=localhost:{iap_port}"
]

print(f"Starting IAP tunnel on port {iap_port}...", file=sys.stderr)
env = os.environ.copy()
env["CLOUDSDK_PYTHON"] = r"C:\Python311\python.exe"

iap_proc = subprocess.Popen(
    iap_cmd,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    env=env
)

# Wait for tunnel to be ready (look for "Listening on port" in stderr)
ready = False
start = time.time()
stderr_lines = []

def read_iap_stderr():
    for line in iap_proc.stderr:
        l = line.decode('utf-8', errors='replace').strip()
        stderr_lines.append(l)
        print(f"IAP: {l}", file=sys.stderr)
        
t = threading.Thread(target=read_iap_stderr, daemon=True)
t.start()

# Give it time to start
time.sleep(15)
print(f"IAP stderr so far: {stderr_lines}", file=sys.stderr)

# Now run plink to connect through the IAP tunnel
plink_cmd = [
    PLINK,
    "-batch",          # No interactive prompts
    "-T",              # No PTY
    "-i", KEY,
    "-P", str(iap_port),
    f"{USER}@localhost",
    REMOTE_COMMAND
]

print(f"Running: {' '.join(plink_cmd)}", file=sys.stderr)
result = subprocess.run(
    plink_cmd,
    capture_output=True,
    text=True,
    timeout=60
)

iap_proc.kill()

print(f"EXIT CODE: {result.returncode}", file=sys.stderr)
print(f"STDERR: {result.stderr[:500]}", file=sys.stderr)
print("=== STDOUT ===")
print(result.stdout)
