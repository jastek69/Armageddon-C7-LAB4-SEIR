variable "enable_aws_gcp_tgw_vpn" {
  description = "Enable AWS-to-GCP VPN integration inputs for Tokyo TGW references."
  type        = bool
  default     = false
}

variable "tokyo_tgw_id" {
  description = "Tokyo Transit Gateway ID used for AWS-to-GCP VPN attachments."
  type        = string
  default     = ""
}

variable "gcp_cloud_router_asn" {
  description = "BGP ASN used by GCP Cloud Router."
  type        = number
  default     = 65515
}

variable "tokyo_tgw_asn" {
  description = "BGP ASN used by Tokyo Transit Gateway for AWS-GCP VPN."
  type        = number
  default     = 65501
}

variable "gcp_ha_vpn_interface_0_ip" {
  description = "Public IP for GCP HA VPN interface 0."
  type        = string
  default     = ""
}

variable "gcp_ha_vpn_interface_1_ip" {
  description = "Public IP for GCP HA VPN interface 1."
  type        = string
  default     = ""
}

variable "aws_gcp_tunnel_inside_cidrs" {
  description = "Four /30 inside CIDRs in tunnel order (t1, t2, t3, t4)."
  type        = list(string)
  default = [
    "169.254.0.8/30",
    "169.254.0.12/30",
    "169.254.0.16/30",
    "169.254.0.20/30"
  ]
}

variable "aws_gcp_psk_tunnel_1" {
  description = "Pre-shared key for AWS-GCP tunnel 1."
  type        = string
  default     = ""
  sensitive   = true
}

variable "aws_gcp_psk_tunnel_2" {
  description = "Pre-shared key for AWS-GCP tunnel 2."
  type        = string
  default     = ""
  sensitive   = true
}

variable "aws_gcp_psk_tunnel_3" {
  description = "Pre-shared key for AWS-GCP tunnel 3."
  type        = string
  default     = ""
  sensitive   = true
}

variable "aws_gcp_psk_tunnel_4" {
  description = "Pre-shared key for AWS-GCP tunnel 4."
  type        = string
  default     = ""
  sensitive   = true
}
