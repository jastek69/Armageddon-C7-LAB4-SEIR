#!/usr/bin/env python3
"""
TGW VPC Attachment Health — subnet coverage and route table association.

Discovers the TGW VPC attachment and shows:
  - Which AZ subnets are currently in the attachment
  - The route table associated with each TGW subnet
  - All running EC2 instances in the VPC and which subnets they're in

Useful for diagnosing TGW AZ coverage gaps (e.g. an instance in AZ-c when
the attachment only covers AZ-a can't receive return traffic from GCP).

Usage:
    python diagnostics/tgw_health.py
"""

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))

from _config import (
    aws, section, print_json,
    get_vpc_id, get_tgw_id, get_tgw_vpc_attachment, get_running_instances,
)


def main():
    vpc_id = get_vpc_id()
    tgw_id = get_tgw_id()
    print(f"VPC ID : {vpc_id}")
    print(f"TGW ID : {tgw_id}")

    section("TGW VPC ATTACHMENT DETAILS")
    attachment = get_tgw_vpc_attachment(tgw_id, vpc_id)
    print_json(attachment)

    if attachment and isinstance(attachment, dict):
        attach_id = attachment.get("AttachId")
        subnet_ids = attachment.get("SubnetIds") or []

        if attach_id:
            section(f"FULL ATTACHMENT OPTIONS ({attach_id})")
            data = aws([
                "ec2", "describe-transit-gateway-vpc-attachments", "--output", "json",
                "--transit-gateway-attachment-ids", attach_id,
                "--query", "TransitGatewayVpcAttachments[0]",
            ])
            print_json(data)

        for subnet_id in subnet_ids:
            section(f"ROUTE TABLE FOR TGW SUBNET {subnet_id}")
            data = aws([
                "ec2", "describe-route-tables", "--output", "json",
                "--filters", f"Name=association.subnet-id,Values={subnet_id}",
                "--query", (
                    "RouteTables[*].{"
                    "ID:RouteTableId,"
                    "Name:Tags[?Key=='Name']|[0].Value,"
                    "Routes:Routes[*].{"
                    "Dest:DestinationCidrBlock,"
                    "TGW:TransitGatewayId,"
                    "GW:GatewayId,"
                    "State:State}}"
                ),
            ])
            print_json(data)

    section("RUNNING EC2 INSTANCES IN VPC (AZ coverage check)")
    instances = get_running_instances(vpc_id)
    print_json(instances)

    # Cross-reference: which AZs have instances vs which AZs the TGW attachment covers
    if attachment and isinstance(attachment, dict):
        tgw_subnet_ids = set(attachment.get("SubnetIds") or [])
        if tgw_subnet_ids and instances:
            tgw_az_data = aws([
                "ec2", "describe-subnets", "--output", "json",
                "--subnet-ids", *tgw_subnet_ids,
                "--query", "Subnets[*].{SubnetId:SubnetId,Az:AvailabilityZone}",
            ])
            tgw_azs = {s["Az"] for s in (tgw_az_data or [])}

            instance_subnet_ids = {i["SubnetId"] for i in instances if i.get("SubnetId")}
            if instance_subnet_ids:
                inst_az_data = aws([
                    "ec2", "describe-subnets", "--output", "json",
                    "--subnet-ids", *instance_subnet_ids,
                    "--query", "Subnets[*].{SubnetId:SubnetId,Az:AvailabilityZone}",
                ])
                inst_azs = {s["Az"] for s in (inst_az_data or [])}

                section("AZ COVERAGE SUMMARY")
                print(f"  TGW attachment AZs : {sorted(tgw_azs)}")
                print(f"  Instance AZs       : {sorted(inst_azs)}")
                gaps = inst_azs - tgw_azs
                if gaps:
                    print(f"\n  *** WARNING: instances in {sorted(gaps)} have no TGW ENI "
                          "— return traffic from GCP will be dropped ***")
                else:
                    print("\n  OK: all instance AZs are covered by TGW attachment.")


if __name__ == "__main__":
    main()
