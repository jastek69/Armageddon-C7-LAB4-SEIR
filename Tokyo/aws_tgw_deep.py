#!/usr/bin/env python3
"""Check TGW route tables and TGW VPC attachment details."""
import subprocess
import json
import os

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

# Check what VPN route table contains (what does it route TO? Does it have 10.235.x.x?)
run_aws([
    "ec2", "search-transit-gateway-routes", "--output", "json",
    "--transit-gateway-route-table-id", "tgw-rtb-096952ec1c6d69ae3",
    "--filters", "Name=state,Values=active",
    "--query", "Routes[*].{Dest:DestinationCidrBlock,Type:Type,State:State,Attach:TransitGatewayAttachments[0].TransitGatewayAttachmentId,AttachType:TransitGatewayAttachments[0].ResourceType}"
], "VPN RT (tgw-rtb-096952ec1c6d69ae3) - ALL ACTIVE ROUTES")

# Check all TGW attachments
run_aws([
    "ec2", "describe-transit-gateway-attachments", "--output", "json",
    "--query", "TransitGatewayAttachments[*].{AttachId:TransitGatewayAttachmentId,State:State,Type:ResourceType,ResId:ResourceId,TgwId:TransitGatewayId,Assoc:Association}"
], "ALL TGW ATTACHMENTS")

# Check TGW itself for default route table
run_aws([
    "ec2", "describe-transit-gateways", "--output", "json",
    "--transit-gateway-ids", "tgw-080444eeb36452c20",
    "--query", "TransitGateways[0].{TgwId:TransitGatewayId,State:State,DefaultRouteTable:Options.DefaultRouteTableId,PropDefaultRT:Options.PropagationDefaultRouteTableId,DefaultAssocRT:Options.AssociationDefaultRouteTableId}"
], "TGW DEFAULTS")

# Check TGW route table associations
run_aws([
    "ec2", "get-transit-gateway-route-table-associations", "--output", "json",
    "--transit-gateway-route-table-id", "tgw-rtb-06811623ff2c4ac1a",
    "--query", "Associations[*].{AttachId:TransitGatewayAttachmentId,State:State,Type:ResourceType,ResId:ResourceId}"
], "MAIN RT ASSOCIATIONS")

run_aws([
    "ec2", "get-transit-gateway-route-table-associations", "--output", "json",
    "--transit-gateway-route-table-id", "tgw-rtb-096952ec1c6d69ae3",
    "--query", "Associations[*].{AttachId:TransitGatewayAttachmentId,State:State,Type:ResourceType,ResId:ResourceId}"
], "VPN RT ASSOCIATIONS")

# Check TGW route table propagations
run_aws([
    "ec2", "get-transit-gateway-route-table-propagations", "--output", "json",
    "--transit-gateway-route-table-id", "tgw-rtb-06811623ff2c4ac1a",
    "--query", "TransitGatewayRouteTablePropagations[*].{AttachId:TransitGatewayAttachmentId,State:State,Type:ResourceType,ResId:ResourceId}"
], "MAIN RT PROPAGATIONS")

run_aws([
    "ec2", "get-transit-gateway-route-table-propagations", "--output", "json",
    "--transit-gateway-route-table-id", "tgw-rtb-096952ec1c6d69ae3",
    "--query", "TransitGatewayRouteTablePropagations[*].{AttachId:TransitGatewayAttachmentId,State:State,Type:ResourceType,ResId:ResourceId}"
], "VPN RT PROPAGATIONS")
