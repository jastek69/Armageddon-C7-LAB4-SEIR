#!/usr/bin/env python3
"""Add a second subnet to the TGW VPC attachment for ap-northeast-1c AZ."""
import subprocess
import json
import os

def run_aws(args, label):
    print(f"\n===== {label} =====")
    cmd = ["aws"] + args + ["--cli-connect-timeout", "5", "--cli-read-timeout", "60"]
    env = {**os.environ, "AWS_DEFAULT_REGION": "ap-northeast-1"}
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=90, env=env)
    if result.returncode != 0:
        print("ERROR:", result.stderr[:500])
        return None
    else:
        try:
            data = json.loads(result.stdout)
            print(json.dumps(data, indent=2))
            return data
        except Exception:
            print(result.stdout)
            return result.stdout

VPC_ID = "vpc-09192bc5409c99d86"
ATTACH_ID = "tgw-attach-0454e0d61697bb548"  # TGW VPC attachment

# Check if there's already a TGW subnet in ap-northeast-1c
# We need to find private-subnet-b (10.233.11.0/24, ap-northeast-1c) 
# or create a dedicated TGW subnet in that AZ

# Option 1: Add the existing private-subnet-b to the TGW attachment  
# This would be subnet-053e22a46dc1fc2e1 (10.233.11.0/24, ap-northeast-1c)
# But adding an instance subnet as TGW subnet is not best practice.

# Option 2: Create a dedicated TGW subnet in ap-northeast-1c
# Let's first check what CIDRs are available in 10.233.100.0/24 range

# First, check what subnets already exist in 10.233.100.x range
run_aws([
    "ec2", "describe-subnets", "--output", "json",
    "--filters", f"Name=vpc-id,Values={VPC_ID}",
    "--query", "Subnets[*].{SubnetId:SubnetId,CidrBlock:CidrBlock,Az:AvailabilityZone,Name:Tags[?Key=='Name']|[0].Value}"
], "ALL SUBNETS IN VPC (check 10.233.100.x availability)")

# Now try to modify the TGW attachment to add another subnet
# We'll use the existing subnet for ap-northeast-1c (private-subnet-b)
# Actually TGW attachment subnets should be dedicated, not shared with instances
# Let's create a minimal /28 subnet for the TGW in ap-northeast-1c

print("\n\n=== PLAN ===")
print("Will create new subnet 10.233.101.0/28 in ap-northeast-1c for TGW attachment")
print("Then modify TGW attachment to include it")
print("This gives TGW an ENI in ap-northeast-1c for traffic to/from 10.233.11.x")
