#!/usr/bin/env python3
"""
VPN Status — AWS VPN tunnel state and BGP telemetry.

Queries:
  - All VPN connections in ap-northeast-1 with per-tunnel status / route count
  - TGW VPN attachments

No hardcoded IDs. Region read from _config.AWS_REGION.

Usage:
    python diagnostics/vpn_status.py
"""

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))

from _config import aws, section, print_json, AWS_REGION


def main():
    section("AWS VPN CONNECTIONS + TUNNEL TELEMETRY")
    data = aws([
        "ec2", "describe-vpn-connections", "--output", "json",
        "--query", (
            "VpnConnections[*].{"
            "VpnId:VpnConnectionId,"
            "State:State,"
            "TgwId:TransitGatewayId,"
            "T1_ip:VgwTelemetry[0].OutsideIpAddress,"
            "T1_status:VgwTelemetry[0].Status,"
            "T1_routes:VgwTelemetry[0].AcceptedRouteCount,"
            "T1_detail:VgwTelemetry[0].StatusMessage,"
            "T2_ip:VgwTelemetry[1].OutsideIpAddress,"
            "T2_status:VgwTelemetry[1].Status,"
            "T2_routes:VgwTelemetry[1].AcceptedRouteCount,"
            "T2_detail:VgwTelemetry[1].StatusMessage}"
        ),
    ])
    print_json(data)

    section("TGW VPN ATTACHMENTS")
    data = aws([
        "ec2", "describe-transit-gateway-attachments", "--output", "json",
        "--filters", "Name=resource-type,Values=vpn",
        "--query", (
            "TransitGatewayAttachments[*].{"
            "AttachId:TransitGatewayAttachmentId,"
            "State:State,"
            "TgwId:TransitGatewayId,"
            "VpnId:ResourceId}"
        ),
    ])
    print_json(data)


if __name__ == "__main__":
    main()
