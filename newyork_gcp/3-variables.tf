variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "taaops"                   # Your GCP Project ID
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-east1"                # Your GCP Region
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "us-east1-b"              # Your GCP Zone
}

variable "tokyo_state_bucket" {
  description = "S3 bucket holding Tokyo Terraform remote state."
  type        = string
  default     = "taaops-terraform-state-tokyo"
}

variable "tokyo_state_key" {
  description = "S3 key for Tokyo Terraform state file."
  type        = string
  default     = "tokyo/terraform.tfstate"
}

variable "tokyo_state_region" {
  description = "AWS region for the Tokyo remote state bucket."
  type        = string
  default     = "ap-northeast-1"
}

variable "enable_aws_gcp_tgw_vpn" {
  description = "Enable AWS <-> GCP TGW VPN resources and Tokyo remote state lookups."
  type        = bool
  default     = true
}

variable "enable_gcp_router_destroy" {
  description = "Expose the GCP router for import/destroy even when VPN is disabled."
  type        = bool
  default     = false
}




# GCP Peering
variable "gcp_advertised_cidr" { type = string }

variable "nihonmachi_gcp_cloud_router_asn" {
  type    = number
  default = 65515
}

variable "tokyo_aws_tgw_asn" {
  type    = number
  default = 65501
}

variable "tunnel1_inside_cidr" { type = string }
variable "tunnel2_inside_cidr" { type = string }
variable "tunnel3_inside_cidr" { type = string }
variable "tunnel4_inside_cidr" { type = string }

variable "psk_tunnel_1" {
  type      = string
  sensitive = true
}

variable "psk_tunnel_2" {
  type      = string
  sensitive = true
}

variable "psk_tunnel_3" {
  type      = string
  sensitive = true
}

variable "psk_tunnel_4" {
  type      = string
  sensitive = true
}



# Iowa TGW reference (from Iowa outputs)
variable "gcp_project_id" {
  type = string
}

variable "gcp_region" {
  type    = string
  default = "us-central1"
}

# New York (Iowa) CIDR
variable "nihonmachi_vpc_cidr" {
  type    = string
  default = "10.235.0.0/16"
}

variable "nihonmachi_subnet_cidr" {
  type    = string
  default = "10.235.1.0/24"
}





# Who is allowed to access the NY private URL (VPN/TGW subnets)
variable "allowed_vpn_cidrs" {
  type    = list(string)
  default = ["10.233.0.0/16"] # students: add AWS Tokyo VPC CIDR, corp VPN CIDR, etc.
}

# Tokyo RDS endpoint (private resolvable/reachable over VPN)
variable "tokyo_rds_host" {
  type    = string
  default = "tokyo-rds-endpoint.example"
}

variable "tokyo_rds_port" {
  type    = number
  default = 3306
}

# DB user is OK to store as plain var; password should not be in TF state (use Secret Manager)
variable "tokyo_rds_user" {
  type    = string
  default = "appuser"
}

# Secret name holding DB password (created outside TF or by TF—your choice)
variable "db_password_secret_name" {
  type    = string
  default = "nihonmachi-tokyo-rds-password"
}

variable "nihonmachi_service_account_email" {
  description = "Service account email for Nihonmachi instances."
  type        = string
}

variable "cas_location" {
  description = "Location for the Google CAS pool and CA."
  type        = string
  default     = "us-central1"
}

variable "cas_pool_id" {
  description = "Google CAS CA pool ID."
  type        = string
  default     = "nihonmachi-cas-pool"
}

variable "cas_ca_id" {
  description = "Google CAS certificate authority ID."
  type        = string
  default     = "nihonmachi-root-ca"
}

variable "ilb_cert_common_name" {
  description = "Common name for the ILB certificate."
  type        = string
  default     = "nihonmachi.internal.jastek.click"
}

variable "ilb_cert_sans" {
  description = "Subject alternative names for the ILB certificate."
  type        = list(string)
  default     = ["nihonmachi.internal.jastek.click"]
}

