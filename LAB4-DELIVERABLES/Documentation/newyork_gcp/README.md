# New York GCP Stack — Nihonmachi Clinic (LAB4)

![Badges](https://img.shields.io/badge/Cloud-AWS-blue?logo=amazon-aws)
![Badges](https://img.shields.io/badge/Cloud-GCP-red?logo=google-cloud)
![Badges](https://img.shields.io/badge/VPN-HA-green)
![Badges](https://img.shields.io/badge/Routing-BGP-informational)

GCP-based stateless compute extension for the LAB4 multi-region medical architecture. All patient data (PHI) remains in the Tokyo AWS region. New York holds only stateless app compute — no database, no read replicas, no persistent PHI storage.

Traffic from GCP VMs reaches the Tokyo Aurora RDS cluster exclusively through an HA VPN + BGP tunnel corridor into the AWS Transit Gateway.

---

## Network Topology

```
GCP New York (10.235.0.0/16)
  nihonmachi-vpc01
  ├── nihonmachi-subnet01         10.235.1.0/24   (app VMs, ILB frontend)
  └── nihonmachi-proxy-only-subnet01  10.235.254.0/24  (INTERNAL_MANAGED ILB envoy proxies)

  Compute
  └── nihonmachi-mig01            2 VMs, no external IPs, autoscaler 2–4
      nihonmachi-app-001          10.235.1.2
      nihonmachi-app-002          10.235.1.3

  Load Balancer
  └── nihonmachi-fr01 (ILB)       10.235.1.4 : 443   INTERNAL_MANAGED / HTTPS

  Egress
  ├── nihonmachi-router01         (Cloud Router for NAT)
  └── nihonmachi-nat01            (Cloud NAT on nihonmachi-subnet01)

  VPN
  ├── gcp-to-aws-vpn-gw           HA VPN Gateway (2 interfaces)
  ├── nihonmachi-router           Cloud Router ASN 65515
  └── 4 × BGP tunnels → AWS TGW shinjuku-tgw01 (ASN 65501)
         Tunnel 1  VPN1/Tun1   169.254.21.0/30
         Tunnel 2  VPN1/Tun2   169.254.22.0/30
         Tunnel 3  VPN2/Tun1   169.254.23.0/30
         Tunnel 4  VPN2/Tun2   169.254.24.0/30

  TLS
  └── nihonmachi-cas-pool         GCP Certificate Authority Service
      nihonmachi-root-ca          SAN: nihonmachi.internal.jastek.click

AWS Tokyo (10.233.0.0/16)
  TGW shinjuku-tgw01
  ├── 2 × Customer Gateways       (GCP HA VPN interface IPs)
  ├── 2 × Site-to-Site VPN connections  (4 tunnels total)
  └── Static routes: 10.235.1.0/24, 10.235.254.0/24 → VPN1 attachment
```

---

## File Structure

```
newyork_gcp/
├── 1-authentication.tf           AWS + GCP provider blocks; reads GCP SA key from secrets manager
├── 2-backend.tf                  S3 remote state (taaops-lab1-terraform-state / newyork-gcp.tfstate)
├── 3-variables.tf                CIDRs, ASNs, PSK variable declarations, GCP zone/region
├── 4-aws-tgw-vpn-connections.tf  AWS Customer Gateways + VPN connections to TGW
├── 5-gcp-vpn-connections.tf      GCP HA VPN gateway, Cloud Router, tunnels, BGP sessions
├── cas-ilb-cert.tf               CAS pool/CA + Google-managed cert for ILB
├── compute.tf                    nihonmachi-mig01 instance template, MIG, autoscaler
├── data.tf                       Remote state read from Tokyo (TGW tunnel CIDRs + public IPs)
├── firewall.tf                   Ingress/egress rules for VPN (UDP 500/4500), ILB health checks
├── ilb.tf                        nihonmachi-fr01 INTERNAL_MANAGED HTTPS load balancer
├── nat.tf                        nihonmachi-router01 / nihonmachi-nat01
├── network.tf                    nihonmachi-vpc01, subnets, proxy-only subnet
├── outputs.tf                    ILB IP, BGP tunnel IPs, VPN gateway interfaces
├── secrets.tf                    GCP SA key secret + version
└── terraform.tfvars              Non-sensitive variable overrides
```

---

## BGP Tunnel Inside CIDRs

| Tunnel | VPN Connection | Inside CIDR   | AWS Peer       | GCP Peer       |
|--------|---------------|---------------|----------------|----------------|
| 1      | VPN1 / Tun1   | 169.254.21.0/30 | 169.254.21.1 | 169.254.21.2  |
| 2      | VPN1 / Tun2   | 169.254.22.0/30 | 169.254.22.1 | 169.254.22.2  |
| 3      | VPN2 / Tun1   | 169.254.23.0/30 | 169.254.23.1 | 169.254.23.2  |
| 4      | VPN2 / Tun2   | 169.254.24.0/30 | 169.254.24.1 | 169.254.24.2  |

---

## Deployment

This stack is deployed from the **LAB4 root** alongside the other three stacks, not standalone.

```bash
# From LAB4 root — deploys all stacks in dependency order
./terraform_startup.sh

# Deploy only this stack
cd newyork_gcp
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -auto-approve
```

**PSK injection** — pre-shared keys are not stored in tfvars. Pass them at plan/apply time:

```bash
export TF_VAR_psk_tunnel_1="<psk1>"
export TF_VAR_psk_tunnel_2="<psk2>"
export TF_VAR_psk_tunnel_3="<psk3>"
export TF_VAR_psk_tunnel_4="<psk4>"
```

**Tokyo remote state dependency** — `data.tf` reads the Tokyo stack's remote state to pull the TGW's VPN tunnel public IPs (used as Customer Gateway IPs on the GCP side). Tokyo must be deployed and its state must exist before running this stack.

---

## Post-Deployment Validation

```bash
# AWS — confirm tunnels UP
aws ec2 describe-vpn-connections \
  --query "VpnConnections[*].{ID:VpnConnectionId,State:State,Telemetry:VgwTelemetry}" \
  --region ap-northeast-1

# GCP — confirm BGP sessions ESTABLISHED
gcloud compute routers get-status nihonmachi-router \
  --region=us-east4 \
  --project=taaops

# Confirm ILB is healthy
gcloud compute backend-services get-health nihonmachi-backend \
  --global=false --region=us-east4 --project=taaops
```

Both HA VPN tunnels per VPN connection should show `UP`. BGP sessions should show `Established`.

---

## Teardown

```bash
# From LAB4 root (destroys all stacks in reverse order)
./terraform_destroy.sh

# Destroy only this stack
cd newyork_gcp
terraform destroy -auto-approve
```

> If Tokyo state is unavailable, set `enable_aws_gcp_tgw_vpn = false` in `terraform.tfvars` before destroy to skip the remote state dependency and VPN resources.

---

## Troubleshooting

| Symptom | Check |
|---------|-------|
| Tunnel DOWN after apply | `time_sleep` of 30s is built in for IKE SA negotiation across vendors — wait ~2 min then re-validate |
| BGP not establishing | Verify ASNs: GCP=65515, AWS TGW=65501; verify tunnel inside IPs match both sides |
| ILB health check failing | Confirm port 443 allowed from `35.191.0.0/16` and `130.211.0.0/22` in `firewall.tf` |
| GCP VMs no internet | nihonmachi-nat01 scoped to nihonmachi-subnet01 — verify subnet tag matches VM template |
| Remote state not found | Tokyo must be applied first; confirm `taaops-lab1-terraform-state/tokyo.tfstate` exists |

---

## Authors

- **Author:** John Sweeney | courtesy T.I.Q.S

