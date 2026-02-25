variable "enable_aws_gcp_tgw_vpn" {
  description = "Enable AWS-to-GCP VPN integration inputs for Tokyo TGW."
  type        = bool
  default     = false
  validation {
    condition = !var.enable_aws_gcp_tgw_vpn || (
      (var.gcp_state_bucket != "" && var.gcp_state_key != "" && var.gcp_state_region != "") ||
      (var.gcp_ha_vpn_interface_0_ip != "" && var.gcp_ha_vpn_interface_1_ip != "")
    )
    error_message = "When enable_aws_gcp_tgw_vpn is true, set GCP remote state (bucket/key/region) or both gcp_ha_vpn_interface_*_ip values."
  }
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

variable "gcp_state_bucket" {
  description = "S3 bucket for GCP Terraform remote state outputs."
  type        = string
  default     = ""
}

variable "gcp_state_key" {
  description = "S3 key for GCP Terraform state file."
  type        = string
  default     = ""
}

variable "gcp_state_region" {
  description = "AWS region for the GCP remote state bucket."
  type        = string
  default     = ""
}

variable "gcp_ilb_internal_ip" {
  description = "Internal ILB IP from GCP (optional override if not using remote state)."
  type        = string
  default     = ""
}

variable "ilb_private_zone_name" {
  description = "Private hosted zone name for ILB access."
  type        = string
  default     = "internal.jastek.click"
}

variable "ilb_private_record_name" {
  description = "Record name within the private zone for the ILB."
  type        = string
  default     = "nihonmachi"
}

variable "aws_gcp_tunnel_inside_cidrs" {
  description = "Four /30 inside CIDRs in tunnel order (t1, t2, t3, t4)."
  type        = list(string)
  default = [
    "169.254.21.0/30",
    "169.254.22.0/30",
    "169.254.23.0/30",
    "169.254.24.0/30"
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

variable "gcp_allowed_db_cidrs" {
  description = "GCP CIDR ranges allowed to reach Tokyo RDS over TGW/VPN."
  type        = list(string)
  default     = ["10.235.0.0/16"]
}

variable "gcp_vpc_cidr" {
  description = "GCP VPC CIDR advertised over TGW/VPN for return routing."
  type        = string
  default     = "10.235.0.0/16"
}

variable "enable_rds_flowlog_alarm" {
  description = "Enable the CloudWatch metric filter and alarm for Tokyo RDS subnet flow logs."
  type        = bool
  default     = false
}

