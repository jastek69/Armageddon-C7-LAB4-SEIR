#!/usr/bin/env python3
"""Query AWS instance details and Tokyo subnet/route table status."""
import subprocess
import json
import os

def run_aws(args, label):
    print(f"\n===== {label} =====")
    cmd = ["aws"] + args + [
        "--cli-connect-timeout", "5", "--cli-read-timeout", "30"
    ]
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

# Get instance details for i-01920f6e0690b79d6
run_aws([
    "ec2", "describe-instances", "--output", "json",
    "--instance-ids", "i-01920f6e0690b79d6",
    "--query", "Reservations[0].Instances[0].{InstanceId:InstanceId,State:State.Name,PrivateIp:PrivateIpAddress,SubnetId:SubnetId,VpcId:VpcId}"
], "SSM TEST INSTANCE")

# Get subnet info for the instance
run_aws([
    "ec2", "describe-subnets", "--output", "json",
    "--filters", "Name=vpc-id,Values=vpc-021e7c7a1eb4bceed",
    "--query", "Subnets[*].{SubnetId:SubnetId,CidrBlock:CidrBlock,Name:Tags[?Key=='Name']|[0].Value}"
], "TOKYO VPC SUBNETS")

# Get TGW route table entries for GCP destination
run_aws([
    "ec2", "search-transit-gateway-routes", "--output", "json",
    "--transit-gateway-route-table-id", "tgw-rtb-06811623ff2c4ac1a",
    "--filters", "Name=type,Values=static",
    "--query", "Routes[*].{Dest:DestinationCidrBlock,Type:Type,State:State,Attach:TransitGatewayAttachments[0].TransitGatewayAttachmentId}"
], "TGW STATIC ROUTES")

run_aws([
    "ec2", "search-transit-gateway-routes", "--output", "json",
    "--transit-gateway-route-table-id", "tgw-rtb-06811623ff2c4ac1a",
    "--filters", "Name=destination-cidr-block,Values=10.235.1.0/24",
    "--query", "Routes[*].{Dest:DestinationCidrBlock,Type:Type,State:State,Attachments:TransitGatewayAttachments}"
], "TGW ROUTES TO 10.235.1.0/24")

# Check Tokyo VPC route tables
run_aws([
    "ec2", "describe-route-tables", "--output", "json",
    "--filters", "Name=vpc-id,Values=vpc-021e7c7a1eb4bceed",
    "--query", "RouteTables[*].{ID:RouteTableId,Assoc:Associations[*].SubnetId,Routes:Routes[*].{Dest:DestinationCidrBlock,Via:TransitGatewayId,State:State,GW:GatewayId,Target:NatGatewayId}}"
], "TOKYO VPC ROUTE TABLES")
