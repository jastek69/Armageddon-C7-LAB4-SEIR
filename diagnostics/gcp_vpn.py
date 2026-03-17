#!/usr/bin/env python3
"""
GCP VPN Status — HA VPN tunnels, BGP sessions, routes, and cloud routers.

Reads GCP project from _config.GCP_PROJECT.
gcloud path resolved automatically (PATH → GCLOUD_PATH → common Windows installs).

Usage:
    python diagnostics/gcp_vpn.py
"""

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))

from _config import gcloud, GCP_PROJECT, GCP_REGION, GCP_ROUTER


def main():
    gcloud(
        ["compute", "vpn-tunnels", "list",
         f"--project={GCP_PROJECT}",
         "--format=table(name,status,detailedStatus,peerIp,region)"],
        label="GCP HA VPN TUNNELS",
    )

    gcloud(
        ["compute", "vpn-gateways", "list",
         f"--project={GCP_PROJECT}",
         "--format=table(name,region,network,"
         "vpnInterfaces[0].ipAddress,vpnInterfaces[1].ipAddress)"],
        label="GCP HA VPN GATEWAYS",
    )

    gcloud(
        ["compute", "routers", "list",
         f"--project={GCP_PROJECT}",
         "--format=table(name,region,network)"],
        label="CLOUD ROUTERS",
    )

    gcloud(
        ["compute", "routers", "get-status", GCP_ROUTER,
         f"--region={GCP_REGION}",
         f"--project={GCP_PROJECT}",
         "--format=json"],
        label=f"BGP SESSION STATUS ({GCP_ROUTER})",
    )

    gcloud(
        ["compute", "routes", "list",
         f"--project={GCP_PROJECT}",
         "--format=table(name,destRange,"
         "nextHopVpnTunnel.basename(),"
         "nextHopGateway,priority,network.basename())"],
        label="ALL GCP ROUTES",
    )


if __name__ == "__main__":
    main()
