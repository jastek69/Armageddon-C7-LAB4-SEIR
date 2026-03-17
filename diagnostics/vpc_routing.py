#!/usr/bin/env python3
"""
VPC Routing — Tokyo VPC subnet map, route tables, and TGW routes.

Discovers the VPC ID and TGW ID from tokyo-outputs.json, then shows:
  - All subnets in the Tokyo VPC
  - All route tables and their routes
  - TGW static routes targeting GCP CIDR (10.235.0.0/16)
  - TGW propagated routes from the VPC attachment

Usage:
    python diagnostics/vpc_routing.py
"""

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))

from _config import (
    aws, section, print_json,
    get_vpc_id, get_tgw_id, get_tgw_route_tables,
)


def main():
    vpc_id = get_vpc_id()
    tgw_id = get_tgw_id()
    print(f"VPC ID : {vpc_id}")
    print(f"TGW ID : {tgw_id}")

    section(f"VPC ({vpc_id})")
    data = aws([
        "ec2", "describe-vpcs", "--output", "json",
        "--vpc-ids", vpc_id,
        "--query", "Vpcs[0].{VpcId:VpcId,CidrBlock:CidrBlock,Name:Tags[?Key=='Name']|[0].Value}",
    ])
    print_json(data)

    section("SUBNETS IN TOKYO VPC")
    data = aws([
        "ec2", "describe-subnets", "--output", "json",
        "--filters", f"Name=vpc-id,Values={vpc_id}",
        "--query", (
            "Subnets[*].{"
            "SubnetId:SubnetId,"
            "CidrBlock:CidrBlock,"
            "Az:AvailabilityZone,"
            "Name:Tags[?Key=='Name']|[0].Value}"
        ),
    ])
    print_json(data)

    section("ROUTE TABLES IN TOKYO VPC")
    data = aws([
        "ec2", "describe-route-tables", "--output", "json",
        "--filters", f"Name=vpc-id,Values={vpc_id}",
        "--query", (
            "RouteTables[*].{"
            "ID:RouteTableId,"
            "Name:Tags[?Key=='Name']|[0].Value,"
            "Assoc:Associations[*].SubnetId,"
            "Routes:Routes[*].{"
            "Dest:DestinationCidrBlock,"
            "TGW:TransitGatewayId,"
            "GW:GatewayId,"
            "NAT:NatGatewayId,"
            "State:State}}"
        ),
    ])
    print_json(data)

    section("TGW ATTACHMENTS FOR THIS VPC")
    data = aws([
        "ec2", "describe-transit-gateway-attachments", "--output", "json",
        "--filters",
        f"Name=vpc-id,Values={vpc_id}",
        "--query", (
            "TransitGatewayAttachments[*].{"
            "AttachId:TransitGatewayAttachmentId,"
            "State:State,"
            "TgwId:TransitGatewayId}"
        ),
    ])
    print_json(data)

    # For each TGW route table, check routes pointing to/from GCP CIDR
    route_tables = get_tgw_route_tables(tgw_id)
    for rt in route_tables:
        rt_id = rt["Id"]
        rt_name = rt.get("Name") or rt_id

        section(f"TGW ROUTES TO GCP (10.235.0.0/16) — {rt_name}")
        data = aws([
            "ec2", "search-transit-gateway-routes", "--output", "json",
            "--transit-gateway-route-table-id", rt_id,
            "--filters", "Name=state,Values=active",
            "--query", (
                "Routes[?starts_with(DestinationCidrBlock,'10.235')]"
                ".{Dest:DestinationCidrBlock,Type:Type,State:State,"
                "AttachId:TransitGatewayAttachments[0].TransitGatewayAttachmentId,"
                "AttachType:TransitGatewayAttachments[0].ResourceType}"
            ),
        ])
        print_json(data)


if __name__ == "__main__":
    main()
