#!/usr/bin/env python3
"""Force-unlock the Terraform state lock."""
import subprocess
import os

TF_DIR = r"c:\Users\John Sweeney\aws\class7\armageddon\jastekAI\SEIR_Foundations\LAB4\Tokyo"
env = os.environ.copy()
env["AWS_DEFAULT_REGION"] = "ap-northeast-1"

LOCK_ID = "a860419d-a6b2-0cdb-602f-93a1ad02a866"

print(f"Force-unlocking state lock {LOCK_ID}...", flush=True)
proc = subprocess.run(
    ["terraform", "force-unlock", "-force", LOCK_ID],
    cwd=TF_DIR,
    capture_output=True,
    text=True,
    input="yes\n",
    env=env,
    timeout=60
)
print("STDOUT:", proc.stdout)
print("STDERR:", proc.stderr[:300])
print("RC:", proc.returncode)
