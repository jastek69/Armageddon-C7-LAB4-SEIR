#!/usr/bin/env python3
"""
TGW Connectivity — wait for TGW VPC attachment to become available, then
fire an SSM test from a Tokyo instance to the GCP ILB.

Useful after a fresh deploy when the TGW attachment is still transitioning.
Discovers all IDs from Terraform outputs and AWS API — no hardcoded values.

Usage:
    python diagnostics/tgw_connectivity.py [--skip-wait] [--instance-id i-xxx]
"""

import argparse
import json
import sys
import time
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))

from _config import (
    aws, section, print_json,
    get_vpc_id, get_tgw_id, get_tgw_vpc_attachment,
    get_gcp_ilb_ip, get_running_instances, AWS_REGION,
)


def wait_for_attachment(attach_id, max_polls=12, interval=15):
    """Poll TGW VPC attachment until state=available. Returns True if ready."""
    print(f"\nPolling TGW attachment {attach_id} (max {max_polls} × {interval}s)...")
    for i in range(max_polls):
        data = aws([
            "ec2", "describe-transit-gateway-vpc-attachments", "--output", "json",
            "--transit-gateway-attachment-ids", attach_id,
            "--query", "TransitGatewayVpcAttachments[0].{State:State,SubnetIds:SubnetIds}",
        ])
        state = data.get("State", "unknown") if isinstance(data, dict) else "unknown"
        subnets = data.get("SubnetIds", []) if isinstance(data, dict) else []
        print(f"  [{i+1}/{max_polls}] state={state}  subnets={subnets}")
        if state == "available":
            print("  READY.")
            return True
        time.sleep(interval)
    print("  Attachment still not available — proceeding anyway.")
    return False


def run_ssm_test(instance_id, target_ip, port=443):
    test_cmd = (
        f"timeout 25 bash -c 'echo > /dev/tcp/{target_ip}/{port}' "
        f"&& echo GCP_REACHABLE || echo GCP_UNREACHABLE"
    )
    print(f"\nSSM test from {instance_id} → {target_ip}:{port}")
    print(f"  Command: {test_cmd}")

    cmd_id = aws([
        "ssm", "send-command",
        "--region", AWS_REGION,
        "--instance-id", instance_id,
        "--document-name", "AWS-RunShellScript",
        "--parameters", f"commands={json.dumps([test_cmd])}",
        "--query", "Command.CommandId",
        "--output", "text",
    ])
    if not cmd_id:
        print("  ERROR: failed to send SSM command.")
        return

    cmd_id = cmd_id.strip()
    print(f"  CommandId: {cmd_id}")
    print("  Waiting 30s for result...")
    time.sleep(30)

    result = aws([
        "ssm", "get-command-invocation",
        "--region", AWS_REGION,
        "--command-id", cmd_id,
        "--instance-id", instance_id,
        "--output", "json",
    ])
    if not result:
        print("  ERROR: could not retrieve command invocation.")
        return

    status = result.get("Status", "?")
    output = result.get("StandardOutputContent", "").strip()
    print(f"\n  Status : {status}")
    print(f"  Output : {output}")

    if "GCP_REACHABLE" in output:
        print(f"\n  *** SUCCESS: TGW corridor to GCP is functional ***")
    else:
        print(f"\n  *** FAILED: {instance_id} cannot reach {target_ip}:{port} ***")
        print("  Check: TGW attachment AZ coverage, route table propagations, GCP firewall rules.")


def main():
    parser = argparse.ArgumentParser(description="Wait for TGW attachment, then test GCP connectivity")
    parser.add_argument("--skip-wait", action="store_true",
                        help="Skip polling — go straight to SSM test")
    parser.add_argument("--instance-id",
                        help="EC2 instance ID to test from (auto-discovered if omitted)")
    args = parser.parse_args()

    vpc_id = get_vpc_id()
    tgw_id = get_tgw_id()
    gcp_ip = get_gcp_ilb_ip()

    print(f"VPC ID     : {vpc_id}")
    print(f"TGW ID     : {tgw_id}")
    print(f"GCP ILB IP : {gcp_ip}")

    section("TGW VPC ATTACHMENT")
    attachment = get_tgw_vpc_attachment(tgw_id, vpc_id)
    print_json(attachment)

    if not attachment or not isinstance(attachment, dict):
        print("\nNo TGW VPC attachment found. Has the stack been deployed?")
        sys.exit(1)

    attach_id = attachment.get("AttachId")

    if not args.skip_wait:
        wait_for_attachment(attach_id)
        print("\nWaiting 10s for TGW ENI routes to propagate...")
        time.sleep(10)

    # Pick the source instance
    if args.instance_id:
        instance_id = args.instance_id
        print(f"\nUsing specified instance: {instance_id}")
    else:
        instances = get_running_instances(vpc_id)
        if not instances:
            print(f"\nNo running instances in VPC {vpc_id}. Is the stack deployed?")
            sys.exit(1)
        instance_id = instances[0]["InstanceId"]
        print(f"\nUsing first running instance: {instance_id}  "
              f"({instances[0].get('PrivateIp','?')}  {instances[0].get('Name','')})")
        print("Override with --instance-id <id> to choose a different one.")

    run_ssm_test(instance_id, gcp_ip)


if __name__ == "__main__":
    main()
