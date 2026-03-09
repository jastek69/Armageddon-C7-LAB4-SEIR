#!/usr/bin/env python3
"""Check TGW subnet route table and VPC attachment details."""
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

TGW_SUBNET = "subnet-0a21ce9416d7ec3e0"  # taaops-tokyo-tgw-subnet (10.233.100.0/28)
VPC_ID = "vpc-09192bc5409c99d86"

# Find route table associated with TGW subnet
run_aws([
    "ec2", "describe-route-tables", "--output", "json",
    "--filters", f"Name=association.subnet-id,Values={TGW_SUBNET}",
    "--query", "RouteTables[*].{ID:RouteTableId,Name:Tags[?Key=='Name']|[0].Value,Routes:Routes[*].{Dest:DestinationCidrBlock,TGW:TransitGatewayId,State:State,GW:GatewayId,VPCEnd:VpcPeeringConnectionId}}"
], f"ROUTE TABLE FOR TGW SUBNET {TGW_SUBNET}")

# Check the VPC attachment details  
run_aws([
    "ec2", "describe-transit-gateway-vpc-attachments", "--output", "json",
    "--transit-gateway-attachment-ids", "tgw-attach-0454e0d61697bb548",
    "--query", "TransitGatewayVpcAttachments[0].{AttachId:TransitGatewayAttachmentId,State:State,VpcId:VpcId,SubnetIds:SubnetIds,Options:Options}"
], "VPC TGW ATTACHMENT DETAILS")

# Check if there are SSM instances in other subnets we can try from
run_aws([
    "ec2", "describe-instances", "--output", "json",
    "--filters", "Name=instance-state-name,Values=running",
    "Name=vpc-id,Values=vpc-09192bc5409c99d86",
    "--query", "Reservations[*].Instances[*].{InstanceId:InstanceId,PrivateIp:PrivateIpAddress,SubnetId:SubnetId,State:State.Name,SSM:Tags[?Key=='aws:ssm:resource-data-sync']|[0].Value}"
], "ALL RUNNING INSTANCES IN TOKYO VPC")

# Check security groups for the SSM instance
run_aws([
    "ec2", "describe-instances", "--output", "json",
    "--instance-ids", "i-01920f6e0690b79d6",
    "--query", "Reservations[0].Instances[0].{SGs:SecurityGroups,SubnetId:SubnetId,PrivateIp:PrivateIpAddress}"
], "SSM INSTANCE - SECURITY GROUPS")

# Check the private route table in detail
run_aws([
    "ec2", "describe-route-tables", "--output", "json",
    "--route-table-ids", "rtb-07a3e2feb5fe4b375",
    "--query", "RouteTables[0].{ID:RouteTableId,Name:Tags[?Key=='Name']|[0].Value,Routes:Routes,Assoc:Associations}"
], "TOKYO PRIVATE RT (rtb-07a3e2feb5fe4b375) FULL DETAIL")
