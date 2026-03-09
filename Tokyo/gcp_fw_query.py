#!/usr/bin/env python3
"""Check GCP firewall rules and instance details."""
import subprocess
import json
import os
import sys

GCLOUD = r"C:\Users\John Sweeney\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd"
env = os.environ.copy()
env["CLOUDSDK_PYTHON"] = r"C:\Python311\python.exe"

def run(args, label):
    print(f"\n===== {label} =====")
    cmd = [GCLOUD] + args
    result = subprocess.run(cmd, capture_output=True, text=True, env=env, timeout=30)
    if result.stdout.strip():
        print(result.stdout)
    if result.returncode != 0 or result.stderr.strip():
        print("STDERR:", result.stderr[:400])

run(["compute", "firewall-rules", "list", 
     "--project=taaops",
     "--filter=network=nihonmachi-vpc01",
     "--format=table(name,direction,priority,sourceRanges.list(),denied[].map().firewall_rule().list():label=DENY,allowed[].map().firewall_rule().list():label=ALLOW,targetTags.list())"],
    "FIREWALL RULES - nihonmachi-vpc01")

run(["compute", "instances", "describe", "nihonmachi-app-r65k",
     "--zone=us-central1-b", "--project=taaops",
     "--format=json(name,networkInterfaces,status,tags,metadata.items)"],
    "INSTANCE - nihonmachi-app-r65k")

run(["compute", "instance-groups", "managed", "list",
     "--project=taaops",
     "--format=table(name,zone,baseInstanceName,size,status)"],
    "MANAGED INSTANCE GROUPS")

run(["compute", "backend-services", "list",
     "--project=taaops",
     "--format=table(name,protocol,loadBalancingScheme,backends[].group.basename())"],
    "BACKEND SERVICES")
