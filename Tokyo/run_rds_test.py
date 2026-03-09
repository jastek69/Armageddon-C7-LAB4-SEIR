#!/usr/bin/env python3
"""
Run rds_test.py on GCP VM.
Now that VPN connectivity is good, we can try:
1. Via IAP tunnel (gcloud iap-tunnel + plink) 
2. Run the rds test and capture the JSON output
"""
import subprocess
import json
import os
import time
import threading
import sys

ZONE = "us-central1-b"
PROJECT = "taaops"
INSTANCE = "nihonmachi-app-r65k"
USER = "jastek_sweeney"

# Use gcloud bat/cmd wrapper on Windows
GCLOUD_CMD = r"C:\Users\John Sweeney\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd"
PLINK_EXE = r"C:\Users\John Sweeney\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin\sdk\plink.exe"
KEY_FILE = os.path.expanduser(r"~\.ssh\google_compute_engine.ppk")

env = os.environ.copy()
env["CLOUDSDK_PYTHON"] = r"C:\Python311\python.exe"

# Make sure putty_force_connect is already set (from previous session)
# gcloud config set ssh/putty_force_connect true  -- already done

REMOTE_CMD = "source /etc/profile.d/tokyo_rds.sh 2>/dev/null; python3 /usr/local/bin/rds_test.py"

# --- Approach: gcloud compute ssh --command=... --quiet
# On Windows with PuTTY, gcloud compute ssh will invoke plink with the right key.
# The --command flag passes a command to run in the SSH session.
# The issue was that output was going to the GUI. Let's try with --quiet and pipe.
# 
# Actually the root issue was that gcloud uses putty.exe (GUI) for interactive sessions.
# For non-interactive (--command), it should use the PuTTY plink.exe.
# Let's test this explicitly.

IAP_PORT = 2255

print("Step 1: Start IAP tunnel...", flush=True)
iap_proc = subprocess.Popen(
    [GCLOUD_CMD, "compute", "start-iap-tunnel", INSTANCE, "22",
     f"--zone={ZONE}", f"--project={PROJECT}",
     f"--local-host-port=localhost:{IAP_PORT}",
     "--verbosity=info"],
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    env=env
)

# Collect stderr for "Listening on port" message
ready_event = threading.Event()
iap_lines = []

def read_stderr():
    for raw in iap_proc.stderr:
        line = raw.decode('utf-8', errors='replace').strip()
        iap_lines.append(line)
        print(f"  IAP: {line}", flush=True)
        if "Listening on port" in line or "listening on port" in line.lower():
            ready_event.set()

t = threading.Thread(target=read_stderr, daemon=True)
t.start()

# Wait up to 20s for tunnel to be ready
print("  Waiting for IAP tunnel to be ready (up to 20s)...", flush=True)
if ready_event.wait(timeout=20):
    print("  IAP tunnel ready!", flush=True)
else:
    print(f"  IAP tunnel not confirmed ready after 20s. Lines so far: {iap_lines[-5:]}", flush=True)
    print("  Proceeding anyway...", flush=True)
time.sleep(2)  # Small buffer

print(f"\nStep 2: SSH via plink to localhost:{IAP_PORT}...", flush=True)
# -hostkey accepts the named host key fingerprint without prompting
HOST_KEY_FP = "SHA256:0/D5B41wCaxqB591jKlSLS/TwmHdkLNMEXIQytPPJHo"
plink_cmd = [
    PLINK_EXE,
    "-batch",
    "-T",
    "-hostkey", HOST_KEY_FP,
    "-i", KEY_FILE,
    "-P", str(IAP_PORT),
    f"{USER}@localhost",
    REMOTE_CMD
]
print(f"  Command: {' '.join(plink_cmd)}", flush=True)

result = subprocess.run(
    plink_cmd,
    capture_output=True,
    text=True,
    timeout=90,
    env=env
)

print(f"\nExit code: {result.returncode}", flush=True)
if result.stdout.strip():
    print(f"STDOUT:\n{result.stdout}", flush=True)
if result.stderr.strip():
    print(f"STDERR:\n{result.stderr[:500]}", flush=True)

# Kill IAP tunnel
iap_proc.kill()
iap_proc.wait(timeout=5)

if result.returncode == 0 and result.stdout.strip():
    print("\n=== rds_test.py OUTPUT ===")
    print(result.stdout.strip())
else:
    print("\nNo output from rds_test.py - will investigate plink issue")
    # Print full IAP log to debug
    print(f"\nFull IAP log ({len(iap_lines)} lines):")
    for l in iap_lines[-20:]:
        print(f"  {l}")
