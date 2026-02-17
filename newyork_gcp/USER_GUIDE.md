# User Guide: AWS ↔ GCP HA VPN w/ BGP

![VPN Topology Diagram](/Screenshots/diagram.jpg)

![Badges](https://img.shields.io/badge/Cloud-AWS-blue?logo=amazon-aws) ![Badges](https://img.shields.io/badge/Cloud-GCP-red?logo=google-cloud) ![Badges](https://img.shields.io/badge/VPN-HA-green) ![Badges](https://img.shields.io/badge/Routing-BGP-informational)

This guide provides a comprehensive, step-by-step walkthrough for establishing a high-availability VPN connection using BGP (Border Gateway Protocol) between Amazon Web Services (AWS) and Google Cloud Platform (GCP). This setup ensures secure, redundant, and dynamic routing between cloud providers and is compliant with RFC 4271.

---

## 🔗 References

- [RFC 4271 – BGP-4](https://datatracker.ietf.org/doc/html/rfc4271)  
- [GCP HA VPN with AWS Tutorial](https://cloud.google.com/network-connectivity/docs/vpn/tutorials/create-ha-vpn-connections-google-cloud-aws)

---

## 📁 Project Structure

## 1. Generate Pre-Shared Keys

Before configuring any cloud resources, generate four secure pre-shared keys (PSKs) that will be used for the tunnels.

### 🔧 Steps

1. Visit [https://pskgen.com/](https://pskgen.com/)
2. Generate four strong 32-character PSKs.
3. Save them securely for later use:
   - **Key 1:** For AWS Tunnel 1
   - **Key 2:** For AWS Tunnel 2
   - **Key 3:** For GCP Tunnel 3
   - **Key 4:** For GCP Tunnel 4

     ![PSK](/Screenshots/PSK.png)

---

## 2. Google Cloud Platform (GCP) Configuration

### 2.1 Create Cloud Router

The Cloud Router manages dynamic BGP sessions for the VPN tunnels.

🔧 **Steps**

1. Navigate to **Network Services > Cloud Router**
2. Click **Create Router**
3. Enter the following:
   - **Name:** `gcp-to-aws-cloud-router`
   - **Description:** `gcp-to-aws-cloud-router`
   - **Network:** `main-vpc` or `default`
   - **Region:** `southamerica-east1` (São Paulo)
   - **Cloud Router ASN:** `65515`
   - **BGP Peer keepalive interval:** `60`
   - **BGP Identifier:** Leave blank
   - **Advertised Routes:** Use default (advertise all visible subnets)

     ![GCP-Cloud-Router-Build](/Screenshots/gcp-cloud-router-build.jpg)

4. Click **Create**

---

### 2.2 Create HA VPN Gateway

🔧 **Steps**

1. Go to **VPC Network > VPN**
2. Click **Create VPN Connection**
3. Select **High-availability (HA) VPN**

   ![GCP-HA-Availability](/Screenshots/gcp-ha-availability.jpg)

4. Set:
   - **Name:** `gcp-to-aws-vpn`
   - **Network:** `main-vpc` or `default`
   - **Region:** `southamerica-east1` (São Paulo)

5. Click **Create & Continue**
6. After creation, copy and note the public IP addresses for **Interface 0** and **Interface 1**. These will be used in AWS.

   ![GCP-HA-VPN-Gateway](/Screenshots/gcp-ha-vpn-gw.jpg)

---

## 3. Amazon Web Services (AWS) Configuration

### 3.1 Create Customer Gateways (CGWs)

These act as representations of the remote GCP VPN gateway on AWS.

🔧 **Steps**

1. Go to **VPC > Virtual Private Network > Customer Gateways**
2. Click **Create Customer Gateway** twice:

   - **Name:** `aws-to-gcp-cgw1`
     - **BGP ASN:** `65515`
     - **IP Address:** GCP Interface 0 public IP

   - **Name:** `aws-to-gcp-cgw2`
     - **BGP ASN:** `65515`
     - **IP Address:** GCP Interface 1 public IP

3. Leave other fields as default.
![AWS-Customer-GW-Results](/Screenshots/aws-customer-gw-results.jpg)

---

### 3.2 Create Virtual Private Gateways (VGWs)

These represent the AWS side of the VPN and are attached to your AWS VPC.

🔧 **Steps**

1. Go to **VPC > Virtual Private Network > Virtual Private Gateways**
2. Click **Create Virtual Private Gateway**:
   - **Name:** `aws-to-gcp-vpn-gw` — **ASN:** `65501`
   ![AWS-Virtual-Private-GW-Results](/Screenshots/aws-virtual-pgw-results.jpg)

---

### 3.3 Create Site-to-Site VPN Connections

🔧 **Steps**

Create two VPN connections:

#### VPN 1 – `aws-to-gcp-vpn1`

- **Virtual Private Gateway:** `aws-to-gcp-vpn-gw`
- **Customer Gateway:** `aws-to-gcp-cgw1`
- **Routing Type:** Dynamic (BGP)
![AWS-VPN-Connection1-Section1](/Screenshots/aws-vpn-connection1-first-section.jpg)

- **Tunnels:**
  - **Tunnel 1:** `169.254.0.8/30`, PSK = Key 1, DH Group 15
  ![AWS-VPN-Connection1-T1-S2](/Screenshots/aws-vpn-connection1-tunnel1-section2.jpg)
  ![AWS-VPN-Connection1-T1-S3](/Screenshots/aws-vpn-connection1-tunnel1-section3.jpg)

  - **Tunnel 2:** `169.254.0.12/30`, PSK = Key 2, DH Group 16
  ![AWS-VPN_Connection2-T2-S1](/Screenshots/aws-vpn-connection1-tunnel2-section1.jpg)
  ![AWS-VPN-Connection1-T1-S3](/Screenshots/aws-vpn-connection1-tunnel1-section3.jpg)

  - **Create VPN connection:**
  ![AWS-VPN1-Last-Section](/Screenshots/aws-vpn-connection1-last-section.jpg)

#### VPN 2 – `aws-to-gcp-vpn2`

- **Virtual Private Gateway:** `aws-to-gcp-vpn-gw`
- **Customer Gateway:** `aws-to-gcp-cgw2`
- **Routing Type:** Dynamic (BGP)
![AWS-VPN-Connection1-Section2](/Screenshots/aws-vpn-connection2-first-section.jpg)

- **Tunnels:**
  - **Tunnel 1:** `169.254.0.16/30`, PSK = Key 3, DH Group 18
  ![AWS-VPN-Connection2-T3-S1](/Screenshots/aws-vpn-connection2-tunnel3-section1.jpg)
  ![AWS-VPN-Connection1-T1-S3](/Screenshots/aws-vpn-connection1-tunnel1-section3.jpg)

  - **Tunnel 2:** `169.254.0.20/30`, PSK = Key 4, DH Group 19
  ![AWS-VPN-Connection2-T4-S1](/Screenshots/aws-vpn-connection2-tunnel4-section1.jpg)
  ![AWS-VPN-Connection1-T1-S3](/Screenshots/aws-vpn-connection1-tunnel1-section3.jpg)

  - **Create VPN connection:**
  ![AWS-VPN2-Last-Section](/Screenshots/aws-vpn-connection2-last-section.jpg)

---

## 4. Back to GCP – Configure VPN Tunnels

### 4.1 Create Peer VPN Gateway

🔧 **Steps**

1. Go to **Hybrid Connectivity > VPN > Peer VPN gateways**
2. Click **Create Peer VPN Gateway**
![GCP-Peer-VPN-GW1](/Screenshots/gcp-peer-vpn-gw1.jpg)

3. Set:
   - **Name:** `gcp-to-aws-peer-vpn-gw`
   - Add all 4 interfaces (use AWS public IPs from tunnel creation)
   ![GCP-Peer-VPN-GW2](Screenshots/gcp-peer-vpn-gw2.jpg)

4. Click **Create**

---

### 4.2 Define VPN Tunnels

🔧 **Steps**

1. Edit the GCP HA VPN gateway
2. Add 4 tunnels:
   - **Tunnel 1 →** Interface 0, Associated peer VPN 0, IKEv2, PSK = Key 1

     ![GCP-VPN-Tunnel1](/Screenshots/gcp-vpn-tunnel-1.jpg)

   - **Tunnel 2 →** Interface 0, Associated peer VPN 1, IKEv2, PSK = Key 2

     ![GCP-VPN-Tunnel2](/Screenshots/gcp-vpn-tunnel-2.jpg)

   - **Tunnel 3 →** Interface 1, Associated peer VPN 2, IKEv2, PSK = Key 3

     ![GCP-VPN-Tunnel3](/Screenshots/gcp-vpn-tunnel-3.jpg)

   - **Tunnel 4 →** Interface 1, Associated peer VPN 3, IKEv2, PSK = Key 4

     ![GCP-VPN-Tunnel4](/Screenshots/gcp-vpn-tunnel-4.jpg)

---

### 4.3 Configure BGP Sessions

Assign static BGP IPs manually:

| Tunnel | GCP IP       | AWS IP       | PSK   | DH Group |
|--------|--------------|--------------|-------|----------|
| 1      | 169.254.0.10 | 169.254.0.9  | Key 1 | 15       |
| 2      | 169.254.0.14 | 169.254.0.13 | Key 2 | 16       |
| 3      | 169.254.0.18 | 169.254.0.17 | Key 3 | 18       |
| 4      | 169.254.0.22 | 169.254.0.21 | Key 4 | 19       |

Use `65501` as the **Peer ASN** for each tunnel.

- **BGP Tunnel 1:**

  ![GCP-BGP-T1-S1](/Screenshots/gcp-bgp-tunnel1-section1.jpg)
  ![GCP-BGP-T1-S2](/Screenshots/gcp-bgp-tunnel1-section2.jpg)
  ![GCP-BGP-T1-Complete](/Screenshots/gcp-bgp-tunnel1-complete.jpg)

---

- **BGP Tunnel 2:**

  ![GCP-BGP-T2-S1](/Screenshots/gcp-bgp-tunnel2-section1.jpg)
  ![GCP-BGP-T2-S2](/Screenshots/gcp-bgp-tunnel2-section2.jpg)
  ![GCP-BGP-T2-Complete](/Screenshots/gcp-bgp-tunnel2-complete.jpg)

---

- **BGP Tunnel 3:**

  ![GCP-BGP-T3-S1](/Screenshots/gcp-bgp-tunnel3-section1.jpg)
  ![GCP-BGP-T3-S2](/Screenshots/gcp-bgp-tunnel3-section2.jpg)
  ![GCP-BGP-T3-Complete](/Screenshots/gcp-bgp-tunnel3-complete.jpg)

---

- **BGP Tunnel 4:**

  ![GCP-BGP-T4-S1](/Screenshots/gcp-bgp-tunnel4-section1.jpg)
  ![GCP-BGP-T4-S2](/Screenshots/gcp-bgp-tunnel4-section2.jpg)
  ![GCP-BGP-T4-Complete](/Screenshots/gcp-bgp-tunnel4-complete.jpg)

---

## 5. Validation

### On GCP

- Go to **VPN Overview**
- Confirm all tunnels show `Status - Established`
- Confirm all BGP sessions show `Status - BGP Established`

- **Final Output**: Objective Complete

  - **Cloud VPN Tunnels:** - All four (4) tunnels are established
    ![GCP-Cloud-VPN-Tunnels](/Screenshots/gcp-cloud-vpn-tunnels.jpg)

  - **Cloud VPN Gateways:** - VPN Gateway linked to all four (4) tunnels
    ![GCP-Cloud-VPN-Gateways](/Screenshots/gcp-cloud-vpn-gateways.jpg)
  
  - **Peer VPN Gateways:** - Peer VPN Gateways used in all four (4) tunnels
  ![GCP-Peer-VPN-Gateways](/Screenshots/gcp-peer-vpn-gateways.jpg)

  - **GCP Cloud Router: (Complete)**
  ![GCP-Cloud-Router-Complete](/Screenshots/gcp-cloud-router-complete.jpg)

### On AWS

- Go to **VPN Connections**
- Under each VPN, verify:
  - Tunnel status = `UP`
  - Routing Details = `1 BGP ROUTES`

### **Final Output**

- `aws-to-gcp-vpn1`- Objective Complete
![AWS-VPN-Connection1-Complete](/Screenshots/aws-vpn-connection1-complete.jpg)

- `aws-to-gcp-vpn2`- Objective Complete
![AWS-VPN-Connection2-Complete](/Screenshots/aws-vpn-connection2-complete.jpg)

---

## 6. Teardown Instructions

To avoid unwanted charges, delete the resources when finished.

### AWS

1. Delete both **VPN Connections**
![Teardown-AWS-VPN-Connections-Results](/Screenshots/teardown-aws-vpn-connections-results.jpg)

2. Delete the **Virtual Private Gateway**
![Teardown-AWS-VPGW-Results](/Screenshots/teardown-aws-vpgw-results.jpg)

3. Delete both **Customer Gateways**
![Teardown-AWS-CGW-Results](/Screenshots/teardown-aws-cgw-results.jpg)

### GCP

1. Delete all *four (4)* **VPN Tunnels**
2. Delete the **Cloud VPN Gateway**
3. Delete the **Peer VPN Gateway**
4. Delete the **Cloud Router**

---

## ✍️ Authors & Acknowledgments

- **Author:** T.I.Q.S.
- **Group Leader:** John Sweeney

### 🙏 Inspiration

This project was built with inspiration, mentorship, and guidance from:

- Sensei **"Darth Malgus" Theo**
- Lord **Beron**
- Sir **Rob**
- Jedi Master **Derrick**

Their wisdom, vision, and unwavering discipline made this mission possible.

---
