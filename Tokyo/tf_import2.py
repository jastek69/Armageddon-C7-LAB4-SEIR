#!/usr/bin/env python3
"""Run terraform plan to see what's different."""
import subprocess
import os

TF_DIR = r"c:\Users\John Sweeney\aws\class7\armageddon\jastekAI\SEIR_Foundations\LAB4\Tokyo"
env = os.environ.copy()
env["AWS_DEFAULT_REGION"] = "ap-northeast-1"

# Run import commands one at a time with output
imports = [
    ("aws_subnet.tokyo_tgw_subnet_c", "subnet-08a6b92dc59c56848"),
    ("aws_route_table_association.tokyo_tgw_subnet_c_rt_assoc", "rtbassoc-06ba28cce761bc022"),
    ("aws_ec2_transit_gateway_route.gcp_app_subnet_static[0]", "tgw-rtb-06811623ff2c4ac1a_10.235.1.0/24"),
    ("aws_ec2_transit_gateway_route.gcp_proxy_subnet_static[0]", "tgw-rtb-06811623ff2c4ac1a_10.235.254.0/24"),
]

for resource_addr, resource_id in imports:
    print(f"\nImporting {resource_addr} = {resource_id}", flush=True)
    proc = subprocess.run(
        ["terraform", "import", "-var-file=terraform.tfvars", resource_addr, resource_id],
        cwd=TF_DIR,
        capture_output=True,
        text=True,
        env=env,
        timeout=120
    )
    if proc.returncode == 0:
        # Show last 3 lines of success output
        lines = proc.stdout.strip().split('\n')
        for l in lines[-3:]:
            print(f"  {l}")
        print(f"  SUCCESS")
    else:
        last_stderr = proc.stderr.strip().split('\n')[-5:]
        last_stdout = proc.stdout.strip().split('\n')[-3:]
        print(f"  FAILED (rc={proc.returncode})")
        for l in last_stderr:
            print(f"  STDERR: {l}")
        for l in last_stdout:
            if l.strip():
                print(f"  STDOUT: {l}")

print("\n\nAll imports done.")
