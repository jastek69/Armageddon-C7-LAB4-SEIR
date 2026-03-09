#!/usr/bin/env python3
"""
Fix TGW AZ coverage:
1. Create TGW subnet in ap-northeast-1c (10.233.101.0/28)
2. Associate private route table with new subnet
3. Modify TGW VPC attachment to include the new subnet
4. Verify by retesting connectivity from 10.233.11.98
"""
import subprocess
import json
import os
import time

env = {**os.environ, "AWS_DEFAULT_REGION": "ap-northeast-1"}

def run_aws(args, label, capture=True):
    print(f"\n===== {label} =====")
    cmd = ["aws"] + args + ["--cli-connect-timeout", "5", "--cli-read-timeout", "60"]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=90, env=env)
    if result.returncode != 0:
        print("ERROR:", result.stderr[:600])
        return None
    else:
        try:
            data = json.loads(result.stdout)
            print(json.dumps(data, indent=2))
            return data
        except Exception:
            if result.stdout.strip():
                print(result.stdout.strip())
            return result.stdout.strip()

VPC_ID = "vpc-09192bc5409c99d86"
ATTACH_ID = "tgw-attach-0454e0d61697bb548"
PRIVATE_RT_ID = "rtb-07a3e2feb5fe4b375"
NEW_SUBNET_CIDR = "10.233.101.0/28"
NEW_AZ = "ap-northeast-1c"

# Step 1: Create the new TGW subnet in ap-northeast-1c
print("\n" + "="*60)
print("STEP 1: Create TGW subnet in ap-northeast-1c")
print("="*60)

subnet_result = run_aws([
    "ec2", "create-subnet",
    "--vpc-id", VPC_ID,
    "--cidr-block", NEW_SUBNET_CIDR,
    "--availability-zone", NEW_AZ,
    "--tag-specifications",
    f'ResourceType=subnet,Tags=[{{Key=Name,Value=taaops-tokyo-tgw-subnet-c}},{{Key=Type,Value=TransitGateway}}]',
    "--output", "json",
    "--query", "Subnet.{SubnetId:SubnetId,CidrBlock:CidrBlock,Az:AvailabilityZone,State:State}"
], "CREATE TGW SUBNET ap-northeast-1c")

if not subnet_result or not isinstance(subnet_result, dict):
    print("FAILED to create subnet")
    exit(1)

new_subnet_id = subnet_result.get("SubnetId")
print(f"\nNew subnet ID: {new_subnet_id}")

# Step 2: Associate the private route table with the new subnet
print("\n" + "="*60)
print("STEP 2: Associate private route table with new TGW subnet")
print("="*60)

run_aws([
    "ec2", "associate-route-table",
    "--subnet-id", new_subnet_id,
    "--route-table-id", PRIVATE_RT_ID,
    "--output", "json",
    "--query", "{AssocId:AssociationId,State:AssociationState.State}"
], "ASSOCIATE ROUTE TABLE")

# Step 3: Modify TGW VPC attachment to include new subnet
print("\n" + "="*60)
print("STEP 3: Modify TGW VPC attachment to include ap-northeast-1c subnet")
print("="*60)

run_aws([
    "ec2", "modify-transit-gateway-vpc-attachment",
    "--transit-gateway-attachment-id", ATTACH_ID,
    "--add-subnet-ids", new_subnet_id,
    "--output", "json",
    "--query", "TransitGatewayVpcAttachment.{AttachId:TransitGatewayAttachmentId,State:State,Subnets:SubnetIds}"
], "MODIFY TGW ATTACHMENT")

print("\nWaiting 30s for attachment to update...")
time.sleep(30)

# Step 4: Verify attachment now has both subnets
run_aws([
    "ec2", "describe-transit-gateway-vpc-attachments",
    "--transit-gateway-attachment-ids", ATTACH_ID,
    "--output", "json",
    "--query", "TransitGatewayVpcAttachments[0].{AttachId:TransitGatewayAttachmentId,State:State,Subnets:SubnetIds}"
], "VERIFY ATTACHMENT SUBNETS")

print(f"\nDone! New subnet: {new_subnet_id}")
print("Next step: Run aws_retest_11.py to verify connectivity from 10.233.11.98")
