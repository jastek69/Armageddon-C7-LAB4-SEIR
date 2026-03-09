#!/usr/bin/env python3
"""Deep-dive into the actual VPC and routing for the test instance."""
import subprocess
import json
import os

def run_aws(args, label):
    print(f"\n===== {label} =====")
    cmd = ["aws"] + args + ["--cli-connect-timeout", "5", "--cli-read-timeout", "30"]
    env = {**os.environ, "AWS_DEFAULT_REGION": "ap-northeast-1"}
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=45, env=env)
    if result.returncode != 0:
        print("ERROR:", result.stderr[:500])
    else:
        try:
            data = json.loads(result.stdout)
            print(json.dumps(data, indent=2))
        except Exception:
            print(result.stdout)

# The instance is in vpc-09192bc5409c99d86
VPC_ID = "vpc-09192bc5409c99d86"
SUBNET_ID = "subnet-053e22a46dc1fc2e1"

# Describe that VPC
run_aws([
    "ec2", "describe-vpcs", "--output", "json",
    "--vpc-ids", VPC_ID,
    "--query", "Vpcs[0].{VpcId:VpcId,CidrBlock:CidrBlock,Name:Tags[?Key=='Name']|[0].Value}"
], f"VPC {VPC_ID}")

# Get subnet info
run_aws([
    "ec2", "describe-subnets", "--output", "json",
    "--subnet-ids", SUBNET_ID,
    "--query", "Subnets[0].{SubnetId:SubnetId,CidrBlock:CidrBlock,VpcId:VpcId,Az:AvailabilityZone,Name:Tags[?Key=='Name']|[0].Value}"
], f"SUBNET {SUBNET_ID}")

# Get all subnets in that VPC
run_aws([
    "ec2", "describe-subnets", "--output", "json",
    "--filters", f"Name=vpc-id,Values={VPC_ID}",
    "--query", "Subnets[*].{SubnetId:SubnetId,CidrBlock:CidrBlock,Az:AvailabilityZone,Name:Tags[?Key=='Name']|[0].Value}"
], f"ALL SUBNETS IN {VPC_ID}")

# Get route tables for that VPC
run_aws([
    "ec2", "describe-route-tables", "--output", "json",
    "--filters", f"Name=vpc-id,Values={VPC_ID}",
    "--query", "RouteTables[*].{ID:RouteTableId,Name:Tags[?Key=='Name']|[0].Value,Assoc:Associations[*].{SubnetId:SubnetId,Main:Main},Routes:Routes[*].{Dest:DestinationCidrBlock,TGW:TransitGatewayId,State:State,GW:GatewayId}}"
], f"ROUTE TABLES IN {VPC_ID}")

# Check TGW attachments for this VPC
run_aws([
    "ec2", "describe-transit-gateway-attachments", "--output", "json",
    "--filters", f"Name=vpc-id,Values={VPC_ID}",
    "--query", "TransitGatewayAttachments[*].{AttachId:TransitGatewayAttachmentId,State:State,TgwId:TransitGatewayId,VpcId:ResourceId}"
], f"TGW ATTACHMENTS FOR VPC {VPC_ID}")

# Get all TGW route tables
run_aws([
    "ec2", "describe-transit-gateway-route-tables", "--output", "json",
    "--query", "TransitGatewayRouteTables[*].{ID:TransitGatewayRouteTableId,State:State,Name:Tags[?Key=='Name']|[0].Value,TgwId:TransitGatewayId}"
], "ALL TGW ROUTE TABLES")

# Search all TGW route tables for 10.233.0.0/16
run_aws([
    "ec2", "search-transit-gateway-routes", "--output", "json",
    "--transit-gateway-route-table-id", "tgw-rtb-06811623ff2c4ac1a",
    "--filters", "Name=type,Values=propagated",
    "--query", "Routes[?DestinationCidrBlock=='10.233.0.0/16' || starts_with(DestinationCidrBlock,'10.233')].{Dest:DestinationCidrBlock,Type:Type,State:State,Attach:TransitGatewayAttachments[0].TransitGatewayAttachmentId}"
], "TGW MAIN RT - 10.233.x.x ROUTES")
