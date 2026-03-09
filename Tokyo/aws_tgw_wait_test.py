#!/usr/bin/env python3
"""Wait for TGW attachment to become available, then retest connectivity."""
import subprocess
import json
import os
import time

env = {**os.environ, "AWS_DEFAULT_REGION": "ap-northeast-1"}
ATTACH_ID = "tgw-attach-0454e0d61697bb548"
INSTANCE_11 = "i-01920f6e0690b79d6"  # 10.233.11.98

def run_aws(args):
    cmd = ["aws"] + args + ["--cli-connect-timeout", "5", "--cli-read-timeout", "30"]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=45, env=env)
    if result.returncode != 0:
        return None, result.stderr
    try:
        return json.loads(result.stdout), None
    except Exception:
        return result.stdout.strip(), None

# Wait for attachment ready
print("Waiting for TGW attachment to become available...")
for i in range(12):
    data, err = run_aws([
        "ec2", "describe-transit-gateway-vpc-attachments",
        "--transit-gateway-attachment-ids", ATTACH_ID,
        "--output", "json",
        "--query", "TransitGatewayVpcAttachments[0].{State:State,Subnets:SubnetIds}"
    ])
    state = data.get("State") if isinstance(data, dict) else "unknown"
    print(f"  [{i+1}/12] State: {state}, Subnets: {data.get('Subnets') if isinstance(data, dict) else 'N/A'}")
    if state == "available":
        print("  READY!")
        break
    time.sleep(15)
else:
    print("Attachment still not available after 3 minutes, proceeding anyway...")

# Give TGW a moment to propagate the new ENI
print("\nWaiting 10s for TGW to propagate new ENI routes...")
time.sleep(10)

# Test from 10.233.11.98
TEST_CMD = "timeout 15 bash -c 'echo > /dev/tcp/10.235.1.3/443' && echo GCP_v5_OPEN || echo GCP_v5_FAILED"
print(f"\nSending SSM test from 10.233.11.98 (i-01920f6e0690b79d6)...")
print(f"Command: {TEST_CMD}")

cmd_data, err = run_aws([
    "ssm", "send-command",
    "--region", "ap-northeast-1",
    "--instance-id", INSTANCE_11,
    "--document-name", "AWS-RunShellScript",
    "--parameters", f"commands={json.dumps([TEST_CMD])}",
    "--query", "Command.CommandId", "--output", "text"
])
if err:
    print(f"ERROR: {err}")
    exit(1)

cmd_id = cmd_data.strip() if isinstance(cmd_data, str) else str(cmd_data)
print(f"CommandId: {cmd_id}")
print("Waiting 25s for result...")
time.sleep(25)

result_data, err = run_aws([
    "ssm", "get-command-invocation",
    "--command-id", cmd_id,
    "--instance-id", INSTANCE_11,
    "--output", "json"
])
if err:
    print(f"ERROR getting result: {err}")
else:
    print(f"Status: {result_data.get('Status')}")
    print(f"Output: {result_data.get('StandardOutputContent','').strip()}")
    out = result_data.get('StandardOutputContent','').strip()
    if "OPEN" in out:
        print("\n*** SUCCESS! 10.233.11.98 can reach GCP! ***")
    else:
        print("\n*** STILL FAILING - need further investigation ***")
