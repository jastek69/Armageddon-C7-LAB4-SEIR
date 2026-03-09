#!/usr/bin/env python3
"""Send SSM command to test GCP reachability from Tokyo RDS subnet."""

import subprocess
import json
import sys
import time

INSTANCE_ID = "i-01920f6e0690b79d6"
REGION = "ap-northeast-1"
COMMAND = "timeout 25 bash -c 'echo > /dev/tcp/10.235.1.3/443' && echo GCP_v4_OPEN || echo GCP_v4_FAILED"

params = json.dumps({"commands": [COMMAND]})

send_cmd = [
    "aws", "ssm", "send-command",
    "--region", REGION,
    "--cli-connect-timeout", "3",
    "--cli-read-timeout", "30",
    "--instance-id", INSTANCE_ID,
    "--document-name", "AWS-RunShellScript",
    "--parameters", f"commands={json.dumps([COMMAND])}",
    "--query", "Command.CommandId",
    "--output", "text"
]

print("Sending SSM command...", file=sys.stderr)
result = subprocess.run(send_cmd, capture_output=True, text=True)
if result.returncode != 0:
    print(f"ERROR sending command: {result.stderr}", file=sys.stderr)
    sys.exit(1)

cmd_id = result.stdout.strip()
print(f"CommandId: {cmd_id}", file=sys.stderr)

print("Waiting 30s for result...", file=sys.stderr)
time.sleep(30)

get_cmd = [
    "aws", "ssm", "get-command-invocation",
    "--region", REGION,
    "--cli-connect-timeout", "3",
    "--cli-read-timeout", "15",
    "--command-id", cmd_id,
    "--instance-id", INSTANCE_ID,
    "--output", "json"
]

result = subprocess.run(get_cmd, capture_output=True, text=True)
if result.returncode != 0:
    print(f"ERROR getting result: {result.stderr}", file=sys.stderr)
    sys.exit(1)

data = json.loads(result.stdout)
print(f"Status: {data.get('Status')}")
print(f"Output: {data.get('StandardOutputContent', '').strip()}")
