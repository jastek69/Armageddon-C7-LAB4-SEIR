#!/usr/bin/env python3
"""Check security groups and run test from 10.233.10.43."""
import subprocess
import json
import os
import time

def run_aws(args, label):
    print(f"\n===== {label} =====")
    cmd = ["aws"] + args + ["--cli-connect-timeout", "5", "--cli-read-timeout", "30"]
    env = {**os.environ, "AWS_DEFAULT_REGION": "ap-northeast-1"}
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=60, env=env)
    if result.returncode != 0:
        print("ERROR:", result.stderr[:500])
    else:
        try:
            data = json.loads(result.stdout)
            print(json.dumps(data, indent=2))
        except Exception:
            print(result.stdout)

# Check security group rules on the EC2 instances
run_aws([
    "ec2", "describe-security-groups", "--output", "json",
    "--group-ids", "sg-02920d669990a3500",
    "--query", "SecurityGroups[0].{ID:GroupId,Name:GroupName,Egress:IpPermissionsEgress[*].{Proto:IpProtocol,Port:FromPort,CIDR:IpRanges[0].CidrIp}}"
], "SECURITY GROUP tokyo_ec2_app_sg - EGRESS")

# Also test from the OTHER instance (10.233.10.43)
INSTANCE_10 = "i-0dc0a5713a92e5d2e"
TEST_CMD = "timeout 12 bash -c 'echo > /dev/tcp/10.235.1.3/443' && echo GCP_FROM_10_OPEN || echo GCP_FROM_10_FAILED"

print(f"\n===== SEND SSM TO 10.233.10.43 ({INSTANCE_10}) =====")
cmd = ["aws", "ssm", "send-command",
       "--region", "ap-northeast-1",
       "--cli-connect-timeout", "3", "--cli-read-timeout", "30",
       "--instance-id", INSTANCE_10,
       "--document-name", "AWS-RunShellScript",
       "--parameters", f"commands={json.dumps([TEST_CMD])}",
       "--query", "Command.CommandId", "--output", "text"]
env = {**os.environ, "AWS_DEFAULT_REGION": "ap-northeast-1"}
result = subprocess.run(cmd, capture_output=True, text=True, timeout=45, env=env)
if result.returncode != 0:
    print("ERROR sending SSM:", result.stderr[:300])
else:
    cmd_id = result.stdout.strip()
    print(f"CommandId: {cmd_id}")
    print("Waiting 20s...")
    time.sleep(20)
    
    get_cmd = ["aws", "ssm", "get-command-invocation",
               "--region", "ap-northeast-1",
               "--cli-connect-timeout", "3", "--cli-read-timeout", "15",
               "--command-id", cmd_id, "--instance-id", INSTANCE_10,
               "--output", "json"]
    result2 = subprocess.run(get_cmd, capture_output=True, text=True, timeout=30, env=env)
    if result2.returncode != 0:
        print("ERROR getting result:", result2.stderr[:300])
    else:
        data = json.loads(result2.stdout)
        print(f"Status: {data.get('Status')}")
        print(f"Output: {data.get('StandardOutputContent','').strip()}")
        print(f"Stderr: {data.get('StandardErrorContent','').strip()[:200]}")
