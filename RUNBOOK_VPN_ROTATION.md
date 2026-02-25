# VPN Rotation Runbook (AWS TGW <-> GCP HA VPN)

## Purpose
Rotate AWS TGW to GCP HA VPN tunnel outside IPs in a controlled window with minimal downtime.

## Scope
- AWS: Tokyo TGW VPN connections and customer gateways.
- GCP: HA VPN gateway, Cloud Router, VPN tunnels, router interfaces, and peers.

## Current Resource Map (Names in Code)
### AWS (Tokyo)
- Customer gateways: `aws_customer_gateway.gcp_cgw_1`, `aws_customer_gateway.gcp_cgw_2` in [Tokyo/main.tf](Tokyo/main.tf#L386-L405).
- VPN connections: `aws_vpn_connection.tgw_vpn_1`, `aws_vpn_connection.tgw_vpn_2` in [Tokyo/main.tf](Tokyo/main.tf#L410-L462).
- TGW route tables: `aws_ec2_transit_gateway_route_table.shinjuku_tgw_rt_main` and `aws_ec2_transit_gateway_route_table.shinjuku_tgw_rt_vpn` in [Tokyo/tgw-route-tables.tf](Tokyo/tgw-route-tables.tf#L1-L18).
- VPN associations/propagations: `gcp_vpn1_assoc`, `gcp_vpn2_assoc`, `gcp_vpn1_prop`, `gcp_vpn2_prop`, `gcp_vpn1_to_vpn_prop`, `gcp_vpn2_to_vpn_prop` in [Tokyo/tgw-route-tables.tf](Tokyo/tgw-route-tables.tf#L30-L114).

### GCP (New York)
- HA VPN gateway: `google_compute_ha_vpn_gateway.gcp-to-aws-vpn-gw` in [newyork_gcp/5-gcp-vpn-connections.tf](newyork_gcp/5-gcp-vpn-connections.tf#L18-L26).
- External VPN gateway: `google_compute_external_vpn_gateway.gcp-to-aws-vpn-gw` in [newyork_gcp/5-gcp-vpn-connections.tf](newyork_gcp/5-gcp-vpn-connections.tf#L27-L52).
- Cloud Router: `google_compute_router.gcp-to-aws-cloud-router` (name `nihonmachi-router`) in [newyork_gcp/5-gcp-vpn-connections.tf](newyork_gcp/5-gcp-vpn-connections.tf#L55-L72).
- VPN tunnels: `google_compute_vpn_tunnel.tunnel0` to `tunnel3` in [newyork_gcp/5-gcp-vpn-connections.tf](newyork_gcp/5-gcp-vpn-connections.tf#L77-L132).
- Router interfaces/peers: `gcp-router-interface-tunnel0..3` and `gcp-router-peer-tunnel0..3` in [newyork_gcp/5-gcp-vpn-connections.tf](newyork_gcp/5-gcp-vpn-connections.tf#L133-L214).

## Preconditions
- Change window approved.
- Current tunnels are up and stable.
- Access to AWS and GCP consoles/CLIs.
- Terraform workspaces ready:
  - Tokyo stack in [Tokyo](Tokyo).
  - GCP stack in [newyork_gcp](newyork_gcp).

## Rotation Strategy (Parallel Build + Cutover)
Create new VPN resources alongside existing ones, validate BGP/route propagation, switch traffic, then remove old resources.

## Step 1: Prepare for Rotation
1) Confirm current tunnel outside IPs in Tokyo outputs.
2) Confirm GCP HA VPN gateway IPs and BGP peers are Established.
3) Record current CIDRs, PSKs, ASNs, and route tables.

## Step 2: Add Parallel VPN Resources
### AWS (Tokyo)
- Create new AWS customer gateways and VPN connections alongside existing ones.
  - Keep existing: `gcp_cgw_1/2` and `tgw_vpn_1/2`.
  - Add new resources with a rotation suffix (example: `gcp_cgw_1_rot`, `gcp_cgw_2_rot`, `tgw_vpn_1_rot`, `tgw_vpn_2_rot`).
- Add TGW associations/propagations for the new VPN attachments to:
  - `shinjuku_tgw_rt_vpn` (associations), and
  - `shinjuku_tgw_rt_main` + `shinjuku_tgw_rt_vpn` (propagations).
- Do not delete existing VPN resources yet.

### GCP (New York)
- Create a second HA VPN gateway and its tunnels/peers (use new names).
  - Keep existing: `gcp-to-aws-vpn-gw`, `tunnel0..3`.
  - Add new resources with a rotation suffix (example: `gcp-to-aws-vpn-gw-rot`, `tunnel0-rot..tunnel3-rot`).
- Create a second external VPN gateway referencing the new AWS tunnel outside IPs from the rotated AWS VPN connections.
- Attach the new tunnels to the same Cloud Router (`gcp-to-aws-cloud-router`) or create a dedicated router for the rotation.

### Full Copy-Paste Block (Rotation Resources)
```hcl
resource "aws_customer_gateway" "gcp_cgw_1_rot" {
  count      = local.gcp_vpn_ready ? 1 : 0
  bgp_asn    = var.gcp_peer_asn
  ip_address = local.gcp_ha_vpn_interface_0_ip_effective
  type       = "ipsec.1"
  tags       = { Name = "gcp-ha-vpn-if0-rot" }
}

resource "aws_customer_gateway" "gcp_cgw_2_rot" {
  count      = local.gcp_vpn_ready ? 1 : 0
  bgp_asn    = var.gcp_peer_asn
  ip_address = local.gcp_ha_vpn_interface_1_ip_effective
  type       = "ipsec.1"
  tags       = { Name = "gcp-ha-vpn-if1-rot" }
}

resource "aws_vpn_connection" "tgw_vpn_1_rot" {
  count               = local.gcp_vpn_ready ? 1 : 0
  transit_gateway_id  = local.effective_tgw_id
  customer_gateway_id = aws_customer_gateway.gcp_cgw_1_rot[0].id
  type                = "ipsec.1"
  static_routes_only  = false

  tunnel1_inside_cidr   = var.tunnel1_inside_cidr
  tunnel1_preshared_key = var.psk_tunnel_1
  tunnel1_ike_versions  = ["ikev2"]

  tunnel2_inside_cidr   = var.tunnel2_inside_cidr
  tunnel2_preshared_key = var.psk_tunnel_2
  tunnel2_ike_versions  = ["ikev2"]

  tags = { Name = "tgw-to-gcp-vpn-1-rot" }
}

resource "aws_vpn_connection" "tgw_vpn_2_rot" {
  count               = local.gcp_vpn_ready ? 1 : 0
  transit_gateway_id  = local.effective_tgw_id
  customer_gateway_id = aws_customer_gateway.gcp_cgw_2_rot[0].id
  type                = "ipsec.1"
  static_routes_only  = false

  tunnel1_inside_cidr   = var.tunnel3_inside_cidr
  tunnel1_preshared_key = var.psk_tunnel_3
  tunnel1_ike_versions  = ["ikev2"]

  tunnel2_inside_cidr   = var.tunnel4_inside_cidr
  tunnel2_preshared_key = var.psk_tunnel_4
  tunnel2_ike_versions  = ["ikev2"]

  tags = { Name = "tgw-to-gcp-vpn-2-rot" }
}

resource "google_compute_ha_vpn_gateway" "gcp-to-aws-vpn-gw-rot" {
  name    = "gcp-to-aws-vpn-gw-rot"
  region  = var.region
  network = google_compute_network.nihonmachi_vpc01.id
}

resource "google_compute_external_vpn_gateway" "gcp-to-aws-vpn-gw-rot" {
  name            = "gcp-to-aws-vpn-gw-rot"
  redundancy_type = "FOUR_IPS_REDUNDANCY"

  interface {
    id         = 0
    ip_address = aws_vpn_connection.tgw_vpn_1_rot[0].tunnel1_address
  }

  interface {
    id         = 1
    ip_address = aws_vpn_connection.tgw_vpn_1_rot[0].tunnel2_address
  }

  interface {
    id         = 2
    ip_address = aws_vpn_connection.tgw_vpn_2_rot[0].tunnel1_address
  }

  interface {
    id         = 3
    ip_address = aws_vpn_connection.tgw_vpn_2_rot[0].tunnel2_address
  }

  depends_on = [aws_vpn_connection.tgw_vpn_1_rot, aws_vpn_connection.tgw_vpn_2_rot]
}

resource "google_compute_vpn_tunnel" "tunnel0_rot" {
  name                            = "tunnel0-rot"
  region                          = var.region
  vpn_gateway                     = google_compute_ha_vpn_gateway.gcp-to-aws-vpn-gw-rot.id
  vpn_gateway_interface           = 0
  peer_external_gateway           = google_compute_external_vpn_gateway.gcp-to-aws-vpn-gw-rot.id
  peer_external_gateway_interface = 0
  shared_secret                   = var.psk_tunnel_1
  router                          = google_compute_router.gcp-to-aws-cloud-router.name
  ike_version                     = 2

  depends_on = [google_compute_ha_vpn_gateway.gcp-to-aws-vpn-gw-rot, google_compute_external_vpn_gateway.gcp-to-aws-vpn-gw-rot]
}

resource "google_compute_vpn_tunnel" "tunnel1_rot" {
  name                            = "tunnel1-rot"
  region                          = var.region
  vpn_gateway                     = google_compute_ha_vpn_gateway.gcp-to-aws-vpn-gw-rot.id
  vpn_gateway_interface           = 0
  peer_external_gateway           = google_compute_external_vpn_gateway.gcp-to-aws-vpn-gw-rot.id
  peer_external_gateway_interface = 1
  shared_secret                   = var.psk_tunnel_2
  router                          = google_compute_router.gcp-to-aws-cloud-router.name
  ike_version                     = 2

  depends_on = [google_compute_ha_vpn_gateway.gcp-to-aws-vpn-gw-rot, google_compute_external_vpn_gateway.gcp-to-aws-vpn-gw-rot]
}

resource "google_compute_vpn_tunnel" "tunnel2_rot" {
  name                            = "tunnel2-rot"
  region                          = var.region
  vpn_gateway                     = google_compute_ha_vpn_gateway.gcp-to-aws-vpn-gw-rot.id
  vpn_gateway_interface           = 1
  peer_external_gateway           = google_compute_external_vpn_gateway.gcp-to-aws-vpn-gw-rot.id
  peer_external_gateway_interface = 2
  shared_secret                   = var.psk_tunnel_3
  router                          = google_compute_router.gcp-to-aws-cloud-router.name
  ike_version                     = 2

  depends_on = [google_compute_ha_vpn_gateway.gcp-to-aws-vpn-gw-rot, google_compute_external_vpn_gateway.gcp-to-aws-vpn-gw-rot]
}

resource "google_compute_vpn_tunnel" "tunnel3_rot" {
  name                            = "tunnel3-rot"
  region                          = var.region
  vpn_gateway                     = google_compute_ha_vpn_gateway.gcp-to-aws-vpn-gw-rot.id
  vpn_gateway_interface           = 1
  peer_external_gateway           = google_compute_external_vpn_gateway.gcp-to-aws-vpn-gw-rot.id
  peer_external_gateway_interface = 3
  shared_secret                   = var.psk_tunnel_4
  router                          = google_compute_router.gcp-to-aws-cloud-router.name
  ike_version                     = 2

  depends_on = [google_compute_ha_vpn_gateway.gcp-to-aws-vpn-gw-rot, google_compute_external_vpn_gateway.gcp-to-aws-vpn-gw-rot]
}

resource "google_compute_router_interface" "gcp-router-interface-tunnel0-rot" {
  name       = "gcp-router-interface-tunnel0-rot"
  router     = google_compute_router.gcp-to-aws-cloud-router.name
  region     = var.region
  ip_range   = "${cidrhost(var.tunnel1_inside_cidr, 2)}/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel0_rot.name

  depends_on = [google_compute_vpn_tunnel.tunnel0_rot]
}

resource "google_compute_router_peer" "gcp-router-peer-tunnel0-rot" {
  name                      = "gcp-router-peer-tunnel0-rot"
  router                    = google_compute_router.gcp-to-aws-cloud-router.name
  region                    = var.region
  peer_ip_address           = cidrhost(var.tunnel1_inside_cidr, 1)
  peer_asn                  = var.tokyo_aws_tgw_asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.gcp-router-interface-tunnel0-rot.name

  depends_on = [google_compute_router_interface.gcp-router-interface-tunnel0-rot]
}

resource "google_compute_router_interface" "gcp-router-interface-tunnel1-rot" {
  name       = "gcp-router-interface-tunnel1-rot"
  router     = google_compute_router.gcp-to-aws-cloud-router.name
  region     = var.region
  ip_range   = "${cidrhost(var.tunnel2_inside_cidr, 2)}/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel1_rot.name

  depends_on = [google_compute_vpn_tunnel.tunnel1_rot]
}

resource "google_compute_router_peer" "gcp-router-peer-tunnel1-rot" {
  name                      = "gcp-router-peer-tunnel1-rot"
  router                    = google_compute_router.gcp-to-aws-cloud-router.name
  region                    = var.region
  peer_ip_address           = cidrhost(var.tunnel2_inside_cidr, 1)
  peer_asn                  = var.tokyo_aws_tgw_asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.gcp-router-interface-tunnel1-rot.name

  depends_on = [google_compute_router_interface.gcp-router-interface-tunnel1-rot]
}

resource "google_compute_router_interface" "gcp-router-interface-tunnel2-rot" {
  name       = "gcp-router-interface-tunnel2-rot"
  router     = google_compute_router.gcp-to-aws-cloud-router.name
  region     = var.region
  ip_range   = "${cidrhost(var.tunnel3_inside_cidr, 2)}/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel2_rot.name

  depends_on = [google_compute_vpn_tunnel.tunnel2_rot]
}

resource "google_compute_router_peer" "gcp-router-peer-tunnel2-rot" {
  name                      = "gcp-router-peer-tunnel2-rot"
  router                    = google_compute_router.gcp-to-aws-cloud-router.name
  region                    = var.region
  peer_ip_address           = cidrhost(var.tunnel3_inside_cidr, 1)
  peer_asn                  = var.tokyo_aws_tgw_asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.gcp-router-interface-tunnel2-rot.name

  depends_on = [google_compute_router_interface.gcp-router-interface-tunnel2-rot]
}

resource "google_compute_router_interface" "gcp-router-interface-tunnel3-rot" {
  name       = "gcp-router-interface-tunnel3-rot"
  router     = google_compute_router.gcp-to-aws-cloud-router.name
  region     = var.region
  ip_range   = "${cidrhost(var.tunnel4_inside_cidr, 2)}/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel3_rot.name

  depends_on = [google_compute_vpn_tunnel.tunnel3_rot]
}

resource "google_compute_router_peer" "gcp-router-peer-tunnel3-rot" {
  name                      = "gcp-router-peer-tunnel3-rot"
  router                    = google_compute_router.gcp-to-aws-cloud-router.name
  region                    = var.region
  peer_ip_address           = cidrhost(var.tunnel4_inside_cidr, 1)
  peer_asn                  = var.tokyo_aws_tgw_asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.gcp-router-interface-tunnel3-rot.name

  depends_on = [google_compute_router_interface.gcp-router-interface-tunnel3-rot]
}
```

### TGW Route Table Associations/Propagations (Rotation)
```hcl
resource "aws_ec2_transit_gateway_route_table_association" "gcp_vpn1_rot_assoc" {
  count = local.gcp_vpn_ready ? 1 : 0

  transit_gateway_attachment_id  = aws_vpn_connection.tgw_vpn_1_rot[0].transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shinjuku_tgw_rt_vpn.id

  depends_on = [aws_vpn_connection.tgw_vpn_1_rot]
}

resource "aws_ec2_transit_gateway_route_table_association" "gcp_vpn2_rot_assoc" {
  count = local.gcp_vpn_ready ? 1 : 0

  transit_gateway_attachment_id  = aws_vpn_connection.tgw_vpn_2_rot[0].transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shinjuku_tgw_rt_vpn.id

  depends_on = [aws_vpn_connection.tgw_vpn_2_rot]
}

resource "aws_ec2_transit_gateway_route_table_propagation" "gcp_vpn1_rot_prop" {
  count = local.gcp_vpn_ready ? 1 : 0

  transit_gateway_attachment_id  = aws_vpn_connection.tgw_vpn_1_rot[0].transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shinjuku_tgw_rt_main.id

  depends_on = [aws_vpn_connection.tgw_vpn_1_rot]
}

resource "aws_ec2_transit_gateway_route_table_propagation" "gcp_vpn2_rot_prop" {
  count = local.gcp_vpn_ready ? 1 : 0

  transit_gateway_attachment_id  = aws_vpn_connection.tgw_vpn_2_rot[0].transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shinjuku_tgw_rt_main.id

  depends_on = [aws_vpn_connection.tgw_vpn_2_rot]
}

resource "aws_ec2_transit_gateway_route_table_propagation" "gcp_vpn1_rot_to_vpn_prop" {
  count = local.gcp_vpn_ready ? 1 : 0

  transit_gateway_attachment_id  = aws_vpn_connection.tgw_vpn_1_rot[0].transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shinjuku_tgw_rt_vpn.id

  depends_on = [aws_vpn_connection.tgw_vpn_1_rot]
}

resource "aws_ec2_transit_gateway_route_table_propagation" "gcp_vpn2_rot_to_vpn_prop" {
  count = local.gcp_vpn_ready ? 1 : 0

  transit_gateway_attachment_id  = aws_vpn_connection.tgw_vpn_2_rot[0].transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shinjuku_tgw_rt_vpn.id

  depends_on = [aws_vpn_connection.tgw_vpn_2_rot]
}
```

## Step 3: Validate New Tunnels
- Verify all new GCP router peers show Established.
- Verify AWS VPN connections show UP for all tunnels.
- Verify routes for GCP CIDRs are learned in TGW route tables.
- Verify connectivity from GCP VM to Tokyo RDS and ILB.

## Step 4: Cutover
- Confirm traffic is flowing through new tunnels.
- Update any monitoring to reference new tunnel IDs if needed.
- Keep old tunnels active for a short soak period.

## Step 5: Remove Old Tunnels
1) Set `prevent_destroy = false` in the VPN lifecycle blocks for:
  - [Tokyo/tgw-vpn-connections.tf](Tokyo/tgw-vpn-connections.tf) (if present)
  - [newyork_gcp/5-gcp-vpn-connections.tf](newyork_gcp/5-gcp-vpn-connections.tf)
2) Remove old VPN resources from Terraform config (the original, non-rotated set).
3) Apply in Tokyo, then apply in newyork_gcp.
4) Set `prevent_destroy = true` again to re-pin resources.

## Step 6: Post-Change Checks
- Confirm BGP peers Established on the new tunnels.
- Confirm TGW route propagation in the VPN route table.
- Confirm flow logs show expected traffic and no REJECT spikes.
- Document new tunnel outside IPs and update any external references.

## Rollback Plan
- If new tunnels fail, keep old tunnels active.
- Remove new resources and revert to the previous state.
- Re-apply with `prevent_destroy = true` to prevent accidental deletion.

## Notes
- The `prevent_destroy` lifecycle guard is set directly on the VPN resources in:
  - [Tokyo/tgw-vpn-connections.tf](Tokyo/tgw-vpn-connections.tf) (if present)
  - [newyork_gcp/5-gcp-vpn-connections.tf](newyork_gcp/5-gcp-vpn-connections.tf)
- Operational toggle: set `prevent_destroy = true` during normal builds/changes, and temporarily set it to `false` only for teardown or planned VPN rotation, then restore to `true`.
- The Tokyo RDS flow log alert is optional; toggle with `enable_rds_flowlog_alarm` in [Tokyo/variables_aws_gcp_tgw.tf](Tokyo/variables_aws_gcp_tgw.tf).
- Use a stable Tokyo remote state key so dependent stacks always read current outputs.

## Build/Apply
- Note: set `prevent_destroy = true` for VPN resources.

## Tear Down
- Note: set `prevent_destroy = false` before destroy, then set it back to `true` after teardown.

Build/ Apply:
Note: set `prevent_destroy = true`

## Secrets manager note:
Option 1: restore secret, then apply:
aws secretsmanager restore-secret \
  --secret-id <secret-name-or-arn> \
  --region ap-northeast-1

example:
aws secretsmanager restore-secret \
  --secret-id taaops/rds/mysql \
  --region ap-northeast-1

Next: Import the existing secret into state.
```
cd Tokyo
terraform import aws_secretsmanager_secret.db_secret taaops/rds/mysql
```

Finally re-run from root


Option 2: force delete, then recreate
Tear Down:
Note: set `prevent_destroy = false`, teardown will require a manual toggle (set to false) before destroy, then set back to true after.


## Reference Docs
- AWS Site-to-Site VPN tunnel changes: https://docs.aws.amazon.com/vpn/latest/s2svpn/modify-vpn-connection.html
- AWS VPN tunnel options: https://docs.aws.amazon.com/vpn/latest/s2svpn/VPNTunnels.html
- GCP HA VPN concepts: https://cloud.google.com/network-connectivity/docs/vpn/concepts/ha-vpn
- GCP HA VPN with Cloud Router: https://cloud.google.com/network-connectivity/docs/router/how-to/creating-ha-vpn
- GCP VPN monitoring: https://cloud.google.com/network-connectivity/docs/vpn/how-to/monitor-vpn
