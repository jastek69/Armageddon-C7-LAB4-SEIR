#!/usr/bin/env python3
"""Query GCP resources using subprocess to capture output."""
import subprocess
import sys
import os

GCLOUD = r"C:\Users\John Sweeney\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin\gcloud"
env = os.environ.copy()
env["CLOUDSDK_PYTHON"] = r"C:\Python311\python.exe"

def run(args, label):
    print(f"\n===== {label} =====")
    result = subprocess.run(
        [GCLOUD] + args,
        capture_output=True, text=True, env=env, timeout=30
    )
    print("STDOUT:", result.stdout)
    if result.stderr:
        print("STDERR:", result.stderr[:300])

run(["compute", "vpn-tunnels", "list", "--project=taaops",
     "--format=table(name,status,detailedStatus,peerIp,region)"],
    "VPN TUNNELS")

run(["compute", "routes", "list", "--project=taaops",
     "--format=table(name,destRange,nextHopVpnTunnel.basename(),nextHopGateway,priority,network.basename())"],
    "ALL ROUTES")

run(["compute", "routers", "list", "--project=taaops",
     "--format=table(name,region,network)"],
    "CLOUD ROUTERS")

run(["compute", "routers", "get-status", "nihonmachi-cr01",
     "--region=us-central1", "--project=taaops",
     "--format=json"],
    "BGP SESSION STATUS")

run(["compute", "vpn-gateways", "list", "--project=taaops",
     "--format=table(name,region,network,vpnInterfaces[0].ipAddress,vpnInterfaces[1].ipAddress)"],
    "HA VPN GATEWAYS")
