# -------------------------------------------------------------------
# Pairing Notes (GCP side)
# -------------------------------------------------------------------
# This file pairs with `4-aws-tgw-vpn-connections.tf.txt`.
# AWS TGW VPN connections generate tunnel outside IPs, and this GCP config
# consumes those IPs in `google_compute_external_vpn_gateway` interfaces.
#
# Keep these values consistent across both sides:
# - Tunnel inside CIDRs (/30)
# - Tunnel pre-shared keys
# - AWS ASN / GCP ASN
# -------------------------------------------------------------------

# GCP Network Infrastructure
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network

# GCP HA VPN Gateway
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_ha_vpn_gateway

resource "google_compute_ha_vpn_gateway" "gcp-to-aws-vpn-gw" {
  count   = var.enable_aws_gcp_tgw_vpn ? 1 : 0
  name    = "gcp-to-aws-vpn-gw"
  region  = var.region
  network = google_compute_network.nihonmachi_vpc01.id

  lifecycle {
    prevent_destroy = false
  }
}

# GCP External VPN Gateway
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_external_vpn_gateway

resource "google_compute_external_vpn_gateway" "gcp-to-aws-vpn-gw" {
  count           = var.enable_aws_gcp_tgw_vpn ? 1 : 0
  name            = "gcp-to-aws-vpn-gw"
  redundancy_type = "FOUR_IPS_REDUNDANCY"

  interface {
    id         = 0
    ip_address = data.terraform_remote_state.tokyo[0].outputs.gcp_tgw_vpn1_tunnel1_address
  }

  interface {
    id         = 1
    ip_address = data.terraform_remote_state.tokyo[0].outputs.gcp_tgw_vpn1_tunnel2_address
  }

  interface {
    id         = 2
    ip_address = data.terraform_remote_state.tokyo[0].outputs.gcp_tgw_vpn2_tunnel1_address
  }

  interface {
    id         = 3
    ip_address = data.terraform_remote_state.tokyo[0].outputs.gcp_tgw_vpn2_tunnel2_address
  }

  lifecycle {
    prevent_destroy = false
  }
}

# GCP Cloud Router
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router

resource "google_compute_router" "gcp-to-aws-cloud-router" {
  count   = (var.enable_aws_gcp_tgw_vpn || var.enable_gcp_router_destroy) ? 1 : 0
  name    = "nihonmachi-router"
  region  = var.region
  network = google_compute_network.nihonmachi_vpc01.id

  bgp {
    asn               = var.nihonmachi_gcp_cloud_router_asn # from Global
    advertise_mode    = "CUSTOM"
    advertised_groups = ["ALL_SUBNETS"]
    advertised_ip_ranges {
      range = var.gcp_advertised_cidr
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}

 



# GCP VPN Tunnels
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_vpn_tunnel

# Tunnel 0
resource "google_compute_vpn_tunnel" "tunnel0" {
  count                           = var.enable_aws_gcp_tgw_vpn ? 1 : 0
  name                            = "tunnel0"
  region                          = var.region
  vpn_gateway                     = google_compute_ha_vpn_gateway.gcp-to-aws-vpn-gw[0].id
  vpn_gateway_interface           = 0
  peer_external_gateway           = google_compute_external_vpn_gateway.gcp-to-aws-vpn-gw[0].id
  peer_external_gateway_interface = 0
  shared_secret                   = var.psk_tunnel_1
  router                          = google_compute_router.gcp-to-aws-cloud-router[0].name
  ike_version                     = 2

  lifecycle {
    prevent_destroy = false
  }

}

# Tunnel 1
resource "google_compute_vpn_tunnel" "tunnel1" {
  count                           = var.enable_aws_gcp_tgw_vpn ? 1 : 0
  name                            = "tunnel1"
  region                          = var.region
  vpn_gateway                     = google_compute_ha_vpn_gateway.gcp-to-aws-vpn-gw[0].id
  vpn_gateway_interface           = 0
  peer_external_gateway           = google_compute_external_vpn_gateway.gcp-to-aws-vpn-gw[0].id
  peer_external_gateway_interface = 1
  shared_secret                   = var.psk_tunnel_2
  router                          = google_compute_router.gcp-to-aws-cloud-router[0].name
  ike_version                     = 2

  lifecycle {
    prevent_destroy = false
  }
}

# Tunnel 2
resource "google_compute_vpn_tunnel" "tunnel2" {
  count                           = var.enable_aws_gcp_tgw_vpn ? 1 : 0
  name                            = "tunnel2"
  region                          = var.region
  vpn_gateway                     = google_compute_ha_vpn_gateway.gcp-to-aws-vpn-gw[0].id
  vpn_gateway_interface           = 1
  peer_external_gateway           = google_compute_external_vpn_gateway.gcp-to-aws-vpn-gw[0].id
  peer_external_gateway_interface = 2
  shared_secret                   = var.psk_tunnel_3
  router                          = google_compute_router.gcp-to-aws-cloud-router[0].name
  ike_version                     = 2

  lifecycle {
    prevent_destroy = false
  }
}

# Tunnel 3
resource "google_compute_vpn_tunnel" "tunnel3" {
  count                           = var.enable_aws_gcp_tgw_vpn ? 1 : 0
  name                            = "tunnel3"
  region                          = var.region
  vpn_gateway                     = google_compute_ha_vpn_gateway.gcp-to-aws-vpn-gw[0].id
  vpn_gateway_interface           = 1
  peer_external_gateway           = google_compute_external_vpn_gateway.gcp-to-aws-vpn-gw[0].id
  peer_external_gateway_interface = 3
  shared_secret                   = var.psk_tunnel_4
  router                          = google_compute_router.gcp-to-aws-cloud-router[0].name
  ike_version                     = 2

  lifecycle {
    prevent_destroy = false
  }
}

# GCP Router Interface and Peer Connection
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_interface
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_peer

# Tunnel 0
resource "google_compute_router_interface" "gcp-router-interface-tunnel0" {
  count    = var.enable_aws_gcp_tgw_vpn ? 1 : 0
  name     = "gcp-router-interface-tunnel0"
  router   = google_compute_router.gcp-to-aws-cloud-router[0].name
  region   = var.region
  ip_range = "${cidrhost(var.tunnel1_inside_cidr, 2)}/30"

  vpn_tunnel = google_compute_vpn_tunnel.tunnel0[0].name

  lifecycle {
    prevent_destroy = false
  }
}

resource "google_compute_router_peer" "gcp-router-peer-tunnel0" {
  count                     = var.enable_aws_gcp_tgw_vpn ? 1 : 0
  name                      = "gcp-router-peer-tunnel0"
  router                    = google_compute_router.gcp-to-aws-cloud-router[0].name
  region                    = var.region
  peer_ip_address           = cidrhost(var.tunnel1_inside_cidr, 1)
  peer_asn                  = var.tokyo_aws_tgw_asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.gcp-router-interface-tunnel0[0].name

  lifecycle {
    prevent_destroy = false
  }
}

# Tunnel 1
resource "google_compute_router_interface" "gcp-router-interface-tunnel1" {
  count      = var.enable_aws_gcp_tgw_vpn ? 1 : 0
  name       = "gcp-router-interface-tunnel1"
  router     = google_compute_router.gcp-to-aws-cloud-router[0].name
  region     = var.region
  ip_range   = "${cidrhost(var.tunnel2_inside_cidr, 2)}/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel1[0].name

  lifecycle {
    prevent_destroy = false
  }
}

resource "google_compute_router_peer" "gcp-router-peer-tunnel1" {
  count                     = var.enable_aws_gcp_tgw_vpn ? 1 : 0
  name                      = "gcp-router-peer-tunnel1"
  router                    = google_compute_router.gcp-to-aws-cloud-router[0].name
  region                    = var.region
  peer_ip_address           = cidrhost(var.tunnel2_inside_cidr, 1)
  peer_asn                  = var.tokyo_aws_tgw_asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.gcp-router-interface-tunnel1[0].name

  lifecycle {
    prevent_destroy = false
  }
}

# Tunnel 2
resource "google_compute_router_interface" "gcp-router-interface-tunnel2" {
  count      = var.enable_aws_gcp_tgw_vpn ? 1 : 0
  name       = "gcp-router-interface-tunnel2"
  router     = google_compute_router.gcp-to-aws-cloud-router[0].name
  region     = var.region
  ip_range   = "${cidrhost(var.tunnel3_inside_cidr, 2)}/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel2[0].name

  lifecycle {
    prevent_destroy = false
  }
}

resource "google_compute_router_peer" "gcp-router-peer-tunnel2" {
  count                     = var.enable_aws_gcp_tgw_vpn ? 1 : 0
  name                      = "gcp-router-peer-tunnel2"
  router                    = google_compute_router.gcp-to-aws-cloud-router[0].name
  region                    = var.region
  peer_ip_address           = cidrhost(var.tunnel3_inside_cidr, 1)
  peer_asn                  = var.tokyo_aws_tgw_asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.gcp-router-interface-tunnel2[0].name

  lifecycle {
    prevent_destroy = false
  }
}

# Tunnel 3
resource "google_compute_router_interface" "gcp-router-interface-tunnel3" {
  count      = var.enable_aws_gcp_tgw_vpn ? 1 : 0
  name       = "gcp-router-interface-tunnel3"
  router     = google_compute_router.gcp-to-aws-cloud-router[0].name
  region     = var.region
  ip_range   = "${cidrhost(var.tunnel4_inside_cidr, 2)}/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel3[0].name

  lifecycle {
    prevent_destroy = false
  }
}

resource "google_compute_router_peer" "gcp-router-peer-tunnel3" {
  count                     = var.enable_aws_gcp_tgw_vpn ? 1 : 0
  name                      = "gcp-router-peer-tunnel3"
  router                    = google_compute_router.gcp-to-aws-cloud-router[0].name
  region                    = var.region
  peer_ip_address           = cidrhost(var.tunnel4_inside_cidr, 1)
  peer_asn                  = var.tokyo_aws_tgw_asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.gcp-router-interface-tunnel3[0].name

  lifecycle {
    prevent_destroy = false
  }
}

