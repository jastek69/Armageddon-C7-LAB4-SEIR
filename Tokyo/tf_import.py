#!/usr/bin/env python3
"""Run terraform import for manually-created resources."""
import subprocess
import os
import sys

TF_DIR = r"c:\Users\John Sweeney\aws\class7\armageddon\jastekAI\SEIR_Foundations\LAB4\Tokyo"
env = os.environ.copy()
env["AWS_DEFAULT_REGION"] = "ap-northeast-1"

def run_tf(args, label, input_text=None):
    print(f"\n===== {label} =====", flush=True)
    cmd = ["terraform"] + args
    print(f"Running: {' '.join(cmd)}", flush=True)
    proc = subprocess.run(
        cmd,
        cwd=TF_DIR,
        capture_output=True,
        text=True,
        input=input_text,
        env=env,
        timeout=120
    )
    if proc.returncode != 0:
        print("STDERR:", proc.stderr[:800])
        print("STDOUT:", proc.stdout[:800])
    else:
        print(proc.stdout[:1000])
    return proc.returncode

# Import the new TGW subnet (ap-northeast-1c)
NEW_SUBNET_ID = "subnet-08a6b92dc59c56848"
run_tf(["import",
        "-var-file=terraform.tfvars",
        "aws_subnet.tokyo_tgw_subnet_c",
        NEW_SUBNET_ID],
       "IMPORT tokyo_tgw_subnet_c")

# Import the route table association for the new subnet
ASSOC_ID = "rtbassoc-06ba28cce761bc022"
run_tf(["import",
        "-var-file=terraform.tfvars",
        "aws_route_table_association.tokyo_tgw_subnet_c_rt_assoc",
        ASSOC_ID],
       "IMPORT tokyo_tgw_subnet_c_rt_assoc")

# Import the static TGW routes
TGW_RT_MAIN = "tgw-rtb-06811623ff2c4ac1a"
run_tf(["import",
        "-var-file=terraform.tfvars",
        "aws_ec2_transit_gateway_route.gcp_app_subnet_static[0]",
        f"{TGW_RT_MAIN}_10.235.1.0/24"],
       "IMPORT gcp_app_subnet_static[0]")

run_tf(["import",
        "-var-file=terraform.tfvars",
        "aws_ec2_transit_gateway_route.gcp_proxy_subnet_static[0]",
        f"{TGW_RT_MAIN}_10.235.254.0/24"],
       "IMPORT gcp_proxy_subnet_static[0]")

# Also import the existing TGW subnet (AZ-a) if not already in state
# (this was created by Terraform originally, but let's verify the attachment change is handled)
print("\n\n===== DONE - Run terraform plan to check drift =====")
