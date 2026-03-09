# Multi-Region Architecture - Tokyo & São Paulo

## Overview
This Terraform configuration implements a secure multi-region AWS architecture with:
- **Tokyo (ap-northeast-1)**: Primary region with secure database
- **São Paulo (sa-east-1)**: Secondary region for distributed compute
- **Transit Gateway**: Secure inter-region connectivity

## Architecture Components

### 🏙️ Tokyo Region (Data Authority)
- **VPC**: `shinjuku_vpc01` (10.233.0.0/16)
- **Subnets**:
  - Public: 10.233.1-3.0/24 (3 AZs)
  - Private: 10.233.10-12.0/24 (3 AZs)
  - TGW: 10.233.100.0/28
- **Database**: Aurora MySQL cluster (private subnets only)
- **Transit Gateway**: `shinjuku_tgw01` (main hub)

### 🌆 São Paulo Region (Compute Spoke)
- **VPC**: `liberdade_vpc01` (10.234.0.0/16)
- **Subnets**: 
  - Public: 10.234.1-3.0/24 (3 AZs)
  - Private: 10.234.10-12.0/24 (3 AZs)
  - TGW: 10.234.100.0/28
- **Compute**: EC2 instances for distributed processing
- **Transit Gateway**: `liberdade_tgw01` (spoke)

## Security Architecture

### 🔒 Database Security
- **Location**: Tokyo region only
- **Access**: 
  - Tokyo EC2 instances (direct VPC access)
  - São Paulo compute (via Transit Gateway only)
  - No public internet access
- **Encryption**: Storage encrypted with KMS

### 🛡️ Network Security
- **Inter-region**: Transit Gateway peering (encrypted)
- **Routing**: Controlled routes between regions
- **Security Groups**: Region-specific with cross-region rules
- **VPC Endpoints**: For AWS services in both regions

### 🔐 ACM Certificates
- **CloudFront**: ACM certificate in us-east-1 for the public CNAMEs.
- **Tokyo ALB Origin**: Separate ACM certificate in ap-northeast-1 for the origin hostname.
- **GCP Internal ILB**: CAS-issued certificate for the internal HTTPS endpoint.
  - CAS pool: `nihonmachi-cas-pool` (us-central1)
  - CA: `nihonmachi-root-ca`
  - Common name/SAN: `nihonmachi.internal.jastek.click`
  - ILB IP: output `nihonmachi_ilb_ip` in [newyork_gcp/outputs.tf](newyork_gcp/outputs.tf#L9-L12)
  - Private DNS: A record in [Tokyo/route53-private-ilb.tf](Tokyo/route53-private-ilb.tf#L9-L22)

## Key Files Updated

### Core Infrastructure
- `[variables.tf](variables.tf)`: Added region-specific CIDR blocks and AZ definitions
- `[02-vpc.tf](02-vpc.tf)`: Tokyo and São Paulo VPCs
- `[03-subnets.tf](03-subnets.tf)`: Multi-region subnet configuration
- `[04-igw-nat.tf](04-igw-nat.tf)`: Internet and NAT gateways for both regions
- `[05-rtb.tf](05-rtb.tf)`: Route tables with cross-region routing

### Tunnel Notes:

time_sleep & triggers:
[time_sleep](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep)
The `time_sleep` breaks the dependency: it forces Terraform to wait 90s after tunnel creation before creating the interfaces, so Cloud Router always sees a live, ESTABLISHED tunnel on first bind.

1. Cross-stack sequencing
Tokyo (Stage 1) creates the AWS TGW VPN connections and outputs the tunnel outside IPs. newyork_gcp (Stage 3) reads those outputs and creates the GCP tunnels. By the time Stage 3 runs, the AWS side has been sitting idle for several minutes waiting. The moment GCP creates its tunnels, AWS is ready to respond immediately — but GCP still needs time to complete its own IKE negotiation.

2. Cross-vendor IKE negotiation is slower
AWS TGW ↔ GCP Cloud VPN have to agree on cipher suites, lifetimes, and DH groups across vendor implementations. That handshake takes 15–45+ seconds. In a GCP↔GCP setup both sides are the same implementation and negotiate in 2–5 seconds — fast enough that Terraform's sequential resource creation naturally "waits" long enough.

3. Cloud Router snapshot behavior
This is the non-obvious part. Cloud Router records the next-hop binding once, at interface creation time. It doesn't watch the tunnel and update when it transitions from NEGOTIATING → ESTABLISHED. So if the interface is created 1 second after the tunnel API call returns — which is what Terraform does without the sleep — it always loses the race on a cross-vendor setup.



### Connectivity & Security
- `[tokyo_tgw.tf](tokyo_tgw.tf)`: Transit Gateway inter-region peering
- `[09-security-groups.tf](09-security-groups.tf)`: Multi-region security groups
- `[15-database.tf](15-database.tf)`: Tokyo-only database configuration

## Network Flow

```
São Paulo Compute → São Paulo TGW → Tokyo TGW → Tokyo Database
```

## Deployment Notes

1. **Provider Configuration**: 
   - Default provider: Tokyo (`ap-northeast-1`)
   - Named provider: São Paulo (`aws.saopaulo`)

2. **Dependencies**:
   - Transit Gateway peering must be established before routing
   - VPC attachments must complete before cross-region communication

3. **Security Compliance**:
   - Database remains in Tokyo (data sovereignty)
   - All cross-region traffic uses encrypted Transit Gateway
   - No direct internet access to database

## Pre-Deploy Sanity Checklist

- Remote state keys align with backends for Tokyo, global, Sao Paulo, and New York GCP stacks.
- Backend locking uses S3 lock files (`use_lockfile = true`) in all stacks.
- Global stack tfvars include `tokyo_state_key`, domain, and subdomain values (CloudFront/Route53 depend on them).
- AWS <-> GCP VPN flags are set for a full deploy: `enable_aws_gcp_tgw_vpn = true` and `enable_gcp_router_destroy = false`.
- Tokyo is configured to pull GCP HA VPN public IPs from remote state via `gcp_state_bucket`, `gcp_state_key`, and `gcp_state_region`.
- New York GCP stack points at Tokyo remote state via `tokyo_state_bucket`, `tokyo_state_key`, and `tokyo_state_region`.
- S3 `force_destroy` matches intent (`true` for dev teardown, `false` for production safety).

## Variables Required

```hcl
# Tokyo Configuration
tokyo_vpc_cidr = "10.233.0.0/16"
tokyo_azs = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]

# São Paulo Configuration  
saopaulo_vpc_cidr = "10.234.0.0/16"
sao_azs = ["sa-east-1a", "sa-east-1b", "sa-east-1c"]
```

## Next Steps

1. **Test Connectivity**: Verify TGW peering and routing
2. **Deploy Applications**: EC2 instances in both regions
3. **Monitor Performance**: Cross-region latency and throughput
4. **Security Validation**: Database access patterns and logging

---

**Architecture Benefits**:
- ✅ Data sovereignty (database in Tokyo)
- ✅ Distributed compute capability
- ✅ Secure cross-region connectivity
- ✅ High availability across regions
- ✅ Scalable Inter-region bandwidth