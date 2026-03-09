resource "aws_ec2_transit_gateway_route_table" "shinjuku_tgw_rt_main" {
  transit_gateway_id = aws_ec2_transit_gateway.shinjuku_tgw01.id

  tags = {
    Name    = "shinjuku-tgw-rt-main"
    Purpose = "DataAuthorityHub"
  }
}

resource "aws_ec2_transit_gateway_route_table" "shinjuku_tgw_rt_vpn" {
  transit_gateway_id = aws_ec2_transit_gateway.shinjuku_tgw01.id

  tags = {
    Name    = "shinjuku-tgw-rt-vpn"
    Purpose = "GCPVPN"
  }
}

# Associate attachments to the managed TGW route table.
resource "aws_ec2_transit_gateway_route_table_association" "tokyo_vpc_assoc" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tokyo_vpc_attachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shinjuku_tgw_rt_main.id
}

resource "aws_ec2_transit_gateway_route_table_association" "tokyo_to_sao_assoc" {
  count = local.saopaulo_peering_enabled ? 1 : 0

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.tokyo_to_sao_peering[0].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shinjuku_tgw_rt_main.id
}

resource "aws_ec2_transit_gateway_route_table_association" "gcp_vpn1_assoc" {
  count = local.gcp_vpn_ready ? 1 : 0

  transit_gateway_attachment_id  = aws_vpn_connection.tgw_vpn_1[0].transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shinjuku_tgw_rt_vpn.id
}

resource "aws_ec2_transit_gateway_route_table_association" "gcp_vpn2_assoc" {
  count = local.gcp_vpn_ready ? 1 : 0

  transit_gateway_attachment_id  = aws_vpn_connection.tgw_vpn_2[0].transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shinjuku_tgw_rt_vpn.id
}

# Propagate routes from attachments into the managed TGW route table.
resource "aws_ec2_transit_gateway_route_table_propagation" "tokyo_vpc_prop" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tokyo_vpc_attachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shinjuku_tgw_rt_main.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "tokyo_vpc_to_vpn_prop" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tokyo_vpc_attachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shinjuku_tgw_rt_vpn.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "tokyo_to_sao_prop" {
  count = local.saopaulo_peering_enabled ? 1 : 0

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.tokyo_to_sao_peering[0].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shinjuku_tgw_rt_main.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "tokyo_to_sao_to_vpn_prop" {
  count = local.saopaulo_peering_enabled ? 1 : 0

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.tokyo_to_sao_peering[0].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shinjuku_tgw_rt_vpn.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "gcp_vpn1_prop" {
  count = local.gcp_vpn_ready ? 1 : 0

  transit_gateway_attachment_id  = aws_vpn_connection.tgw_vpn_1[0].transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shinjuku_tgw_rt_main.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "gcp_vpn2_prop" {
  count = local.gcp_vpn_ready ? 1 : 0

  transit_gateway_attachment_id  = aws_vpn_connection.tgw_vpn_2[0].transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shinjuku_tgw_rt_main.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "gcp_vpn1_to_vpn_prop" {
  count = local.gcp_vpn_ready ? 1 : 0

  transit_gateway_attachment_id  = aws_vpn_connection.tgw_vpn_1[0].transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shinjuku_tgw_rt_vpn.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "gcp_vpn2_to_vpn_prop" {
  count = local.gcp_vpn_ready ? 1 : 0

  transit_gateway_attachment_id  = aws_vpn_connection.tgw_vpn_2[0].transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shinjuku_tgw_rt_vpn.id
}

# Static routes in the main TGW RT to force GCP-bound traffic through vpn_1 attachment.
# vpn_1 (tgw-attach-008cccfd2ca6f9fba) is the active path: GCP tunnel00 peers with
# vpn_1's outside IP, making vpn_1 the preferred return path for GCP subnets.
# Static routes take precedence over propagated ECMP routes for the same prefix.
resource "aws_ec2_transit_gateway_route" "gcp_app_subnet_static" {
  count = local.gcp_vpn_ready ? 1 : 0

  destination_cidr_block         = "10.235.1.0/24"
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shinjuku_tgw_rt_main.id
  transit_gateway_attachment_id  = aws_vpn_connection.tgw_vpn_1[0].transit_gateway_attachment_id
}

resource "aws_ec2_transit_gateway_route" "gcp_proxy_subnet_static" {
  count = local.gcp_vpn_ready ? 1 : 0

  destination_cidr_block         = "10.235.254.0/24"
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shinjuku_tgw_rt_main.id
  transit_gateway_attachment_id  = aws_vpn_connection.tgw_vpn_1[0].transit_gateway_attachment_id
}
