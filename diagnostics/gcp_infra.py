#!/usr/bin/env python3
"""
GCP Infrastructure — firewall rules, MIG status, backend health, and instance details.

Discovers running nihonmachi-app VM name dynamically via gcloud.
Reads GCP project / VPC name from _config constants.

Usage:
    python diagnostics/gcp_infra.py
"""

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))

from _config import gcloud, get_gcp_vm, GCP_PROJECT, GCP_VPC, GCP_REGION


def main():
    vm_name, vm_zone = get_gcp_vm()

    gcloud(
        ["compute", "instances", "list",
         f"--project={GCP_PROJECT}",
         "--filter=name~nihonmachi-app",
         "--format=table(name,zone,machineType.basename(),networkInterfaces[0].networkIP,status)"],
        label="NIHONMACHI APP INSTANCES",
    )

    gcloud(
        ["compute", "instance-groups", "managed", "list",
         f"--project={GCP_PROJECT}",
         "--format=table(name,location,baseInstanceName,size,targetSize,status)"],
        label="MANAGED INSTANCE GROUPS",
    )

    gcloud(
        ["compute", "backend-services", "list",
         f"--project={GCP_PROJECT}",
         "--format=table(name,protocol,loadBalancingScheme,region.basename())"],
        label="BACKEND SERVICES",
    )

    gcloud(
        ["compute", "backend-services", "get-health", "nihonmachi-backend01",
         f"--region={GCP_REGION}",
         f"--project={GCP_PROJECT}"],
        label="BACKEND HEALTH (nihonmachi-backend01)",
    )

    gcloud(
        ["compute", "firewall-rules", "list",
         f"--project={GCP_PROJECT}",
         f"--filter=network={GCP_VPC}",
         "--format=table(name,direction,priority,"
         "sourceRanges.list(),"
         "denied[].map().firewall_rule().list():label=DENY,"
         "allowed[].map().firewall_rule().list():label=ALLOW,"
         "targetTags.list())"],
        label=f"FIREWALL RULES — {GCP_VPC}",
    )

    if vm_name:
        gcloud(
            ["compute", "instances", "describe", vm_name,
             f"--zone={vm_zone}",
             f"--project={GCP_PROJECT}",
             "--format=json(name,networkInterfaces,status,tags,metadata.items)"],
            label=f"INSTANCE DETAIL — {vm_name} ({vm_zone})",
        )
    else:
        print("\n[gcp_infra] No running nihonmachi-app instance found — is the stack deployed?")


if __name__ == "__main__":
    main()
