#!/usr/bin/env python3
"""Query AWS VPN connection details."""
import subprocess
import json
import sys
import os

AWS = "aws"

def run_aws(args, label):
    print(f"\n===== {label} =====")
    cmd = [AWS] + args + ["--cli-connect-timeout", "5", "--cli-read-timeout", "30"]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=45,
                            env={**os.environ, "AWS_DEFAULT_REGION": "ap-northeast-1"})
    if result.returncode != 0:
        print("ERROR:", result.stderr[:500])
    else:
        try:
            data = json.loads(result.stdout)
            print(json.dumps(data, indent=2))
        except Exception:
            print(result.stdout)

run_aws([
    "ec2", "describe-vpn-connections", "--output", "json",
    "--query", "VpnConnections[*].{VpnId:VpnConnectionId,State:State,"
               "TgwId:TransitGatewayId,"
               "T1_ip:VgwTelemetry[0].OutsideIpAddress,"
               "T1_status:VgwTelemetry[0].Status,"
               "T1_detail:VgwTelemetry[0].StatusMessage,"
               "T2_ip:VgwTelemetry[1].OutsideIpAddress,"
               "T2_status:VgwTelemetry[1].Status,"
               "T2_detail:VgwTelemetry[1].StatusMessage}"
], "AWS VPN CONNECTIONS + TELEMETRY")

run_aws([
    "ec2", "describe-transit-gateway-attachments", "--output", "json",
    "--filters", "Name=resource-type,Values=vpn",
    "--query", "TransitGatewayAttachments[*].{AttachId:TransitGatewayAttachmentId,State:State,TgwId:TransitGatewayId,ResId:ResourceId}"
], "TGW VPN ATTACHMENTS")
