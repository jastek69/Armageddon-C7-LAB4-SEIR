#!/usr/bin/env python3
"""
SSM GCP Ping — test GCP ILB reachability from a Tokyo EC2 instance via SSM.

Discovers:
  - GCP ILB IP from newyork-gcp-outputs.json
  - A running EC2 instance in the Tokyo VPC to send the test from

Optionally override the source instance:
    python diagnostics/ssm_gcp_ping.py --instance-id i-0abc123def456

Usage:
    python diagnostics/ssm_gcp_ping.py [--instance-id <id>] [--port 443]
"""

import argparse
import json
import sys
import time
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))

from _config import aws, section, get_vpc_id, get_gcp_ilb_ip, get_running_instances, AWS_REGION


def send_ssm_test(instance_id, target_ip, port, region=AWS_REGION):
    test_cmd = (
        f"timeout 20 bash -c 'echo > /dev/tcp/{target_ip}/{port}' "
        f"&& echo GCP_REACHABLE || echo GCP_UNREACHABLE"
    )

    print(f"\nSending SSM command to {instance_id}")
    print(f"  Target  : {target_ip}:{port}")
    print(f"  Command : {test_cmd}")

    result = aws([
        "ssm", "send-command",
        "--region", region,
        "--instance-id", instance_id,
        "--document-name", "AWS-RunShellScript",
        "--parameters", f"commands={json.dumps([test_cmd])}",
        "--query", "Command.CommandId",
        "--output", "text",
    ])
    if not result:
        print("ERROR: failed to send SSM command.")
        return

    cmd_id = result.strip()
    print(f"  CommandId: {cmd_id}")
    print("  Waiting 30s for result...")
    time.sleep(30)

    invocation = aws([
        "ssm", "get-command-invocation",
        "--region", region,
        "--command-id", cmd_id,
        "--instance-id", instance_id,
        "--output", "json",
    ])
    if not invocation:
        print("ERROR: could not retrieve command result.")
        return

    status = invocation.get("Status", "Unknown")
    output = invocation.get("StandardOutputContent", "").strip()
    stderr = invocation.get("StandardErrorContent", "").strip()

    print(f"\n  Status : {status}")
    print(f"  Output : {output}")
    if stderr:
        print(f"  Stderr : {stderr[:300]}")

    if "GCP_REACHABLE" in output:
        print(f"\n  *** SUCCESS: {instance_id} can reach {target_ip}:{port} ***")
    else:
        print(f"\n  *** FAILED: {instance_id} cannot reach {target_ip}:{port} ***")


def main():
    parser = argparse.ArgumentParser(description="SSM GCP reachability ping")
    parser.add_argument("--instance-id", help="EC2 instance ID to test from (auto-discovered if omitted)")
    parser.add_argument("--port", type=int, default=443, help="Port to test (default 443)")
    args = parser.parse_args()

    gcp_ip = get_gcp_ilb_ip()
    print(f"GCP ILB target: {gcp_ip}:{args.port}")

    if args.instance_id:
        instance_id = args.instance_id
        print(f"Using specified instance: {instance_id}")
    else:
        vpc_id = get_vpc_id()
        instances = get_running_instances(vpc_id)
        if not instances:
            print(f"No running instances found in VPC {vpc_id}. Is the stack deployed?")
            sys.exit(1)

        section("AVAILABLE EC2 INSTANCES")
        for i, inst in enumerate(instances):
            print(f"  [{i}] {inst['InstanceId']}  {inst.get('PrivateIp','?')}  "
                  f"{inst.get('Name','(no name)')}")
        # Default to first instance
        instance_id = instances[0]["InstanceId"]
        print(f"\nUsing first instance: {instance_id}  "
              f"({instances[0].get('PrivateIp','?')}  {instances[0].get('Name','')})")
        print("Override with --instance-id <id> to choose a different one.\n")

    send_ssm_test(instance_id, gcp_ip, args.port)


if __name__ == "__main__":
    main()
