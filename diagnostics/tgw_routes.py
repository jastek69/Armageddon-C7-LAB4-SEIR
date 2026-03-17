#!/usr/bin/env python3
"""
TGW Routes — Transit Gateway route table deep-dive.

Discovers the TGW ID from tokyo-outputs.json, then for every route table
belonging to that TGW shows:
  - All active routes
  - Route table associations
  - Route table propagations
  - TGW-level defaults

Usage:
    python diagnostics/tgw_routes.py
"""

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))

from _config import aws, section, print_json, get_tgw_id, get_tgw_route_tables


def main():
    tgw_id = get_tgw_id()
    print(f"TGW ID: {tgw_id}")

    section(f"TGW DEFAULTS ({tgw_id})")
    data = aws([
        "ec2", "describe-transit-gateways", "--output", "json",
        "--transit-gateway-ids", tgw_id,
        "--query", (
            "TransitGateways[0].{"
            "TgwId:TransitGatewayId,"
            "State:State,"
            "DefaultRouteTable:Options.DefaultRouteTableId,"
            "AssocDefaultRT:Options.AssociationDefaultRouteTableId,"
            "PropDefaultRT:Options.PropagationDefaultRouteTableId}"
        ),
    ])
    print_json(data)

    section("ALL TGW ATTACHMENTS")
    data = aws([
        "ec2", "describe-transit-gateway-attachments", "--output", "json",
        "--query", (
            "TransitGatewayAttachments[*].{"
            "AttachId:TransitGatewayAttachmentId,"
            "State:State,"
            "Type:ResourceType,"
            "ResId:ResourceId,"
            "TgwId:TransitGatewayId,"
            "AssocRT:Association.TransitGatewayRouteTableId}"
        ),
    ])
    print_json(data)

    route_tables = get_tgw_route_tables(tgw_id)
    if not route_tables:
        print("\nNo route tables found for TGW — is the stack deployed?")
        return

    for rt in route_tables:
        rt_id = rt["Id"]
        rt_name = rt.get("Name") or rt_id

        section(f"ACTIVE ROUTES — {rt_name} ({rt_id})")
        data = aws([
            "ec2", "search-transit-gateway-routes", "--output", "json",
            "--transit-gateway-route-table-id", rt_id,
            "--filters", "Name=state,Values=active",
            "--query", (
                "Routes[*].{"
                "Dest:DestinationCidrBlock,"
                "Type:Type,"
                "State:State,"
                "AttachId:TransitGatewayAttachments[0].TransitGatewayAttachmentId,"
                "AttachType:TransitGatewayAttachments[0].ResourceType}"
            ),
        ])
        print_json(data)

        section(f"ASSOCIATIONS — {rt_name} ({rt_id})")
        data = aws([
            "ec2", "get-transit-gateway-route-table-associations", "--output", "json",
            "--transit-gateway-route-table-id", rt_id,
            "--query", (
                "Associations[*].{"
                "AttachId:TransitGatewayAttachmentId,"
                "State:State,"
                "Type:ResourceType,"
                "ResId:ResourceId}"
            ),
        ])
        print_json(data)

        section(f"PROPAGATIONS — {rt_name} ({rt_id})")
        data = aws([
            "ec2", "get-transit-gateway-route-table-propagations", "--output", "json",
            "--transit-gateway-route-table-id", rt_id,
            "--query", (
                "TransitGatewayRouteTablePropagations[*].{"
                "AttachId:TransitGatewayAttachmentId,"
                "State:State,"
                "Type:ResourceType,"
                "ResId:ResourceId}"
            ),
        ])
        print_json(data)


if __name__ == "__main__":
    main()
