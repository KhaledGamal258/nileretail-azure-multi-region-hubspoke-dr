# Costing and component sizing

> **Pricing snapshot date:** **2026-01-09**  
> **Offer:** PAYG unless otherwise noted (Reserved pricing shown below)  
> **Licensing:** Microsoft Online Services Agreement (MOSA)  
> **Important:** These are **estimates only**. Actual costs vary with traffic (requests/egress), scaling (instances/auto-scale), retention, and Reserved commitment choices.

---

## Monthly cost summary (USD)

| Pricing model | Estimated monthly total |
|---|---:|
| **PAYG** | **$6,931.53 / month** |
| **1‑Year RI** | **$6,342.29 / month** |
| **3‑Year RI** | **$6,005.56 / month** |

**Estimated savings vs PAYG**

- **1‑Year RI:** $589.24 / month (~8.5% saving)
- **3‑Year RI:** $925.97 / month (~13.4% saving)

---

## Service-by-service breakdown (USD/month)

> Source: Azure Pricing Calculator export (**2026-01-09**).  
> Regions reflect the design: **Hub (UK South)** + **Spoke‑A (North Europe)** + **Spoke‑B (West Europe)** + **Global** edge services.

| Category | Service | Region | Description | PAYG/month | 1‑Year RI | 3‑Year RI |
|---|---|---|---|---:|---:|---:|
| Networking | Azure Front Door Premium | Global | Base instance, 200 GB egress to client, 200 GB egress to origin, requests | 350.50 | 350.50 | 350.50 |
| Networking | VPN Gateway VpnGw1AZ | West Europe | 730 hrs, 1 TB processed | 227.22 | 227.22 | 227.22 |
| Networking | VPN Gateway VpnGw1AZ | North Europe | 730 hrs, 1 TB processed | 227.22 | 227.22 | 227.22 |
| Networking | VPN Gateway VpnGw1AZ | UK South | 730 hrs, 1 TB processed | 227.22 | 227.22 | 227.22 |
| Networking | Azure Firewall Premium | UK South | 1 logical firewall unit × 730 hrs, 1 TB data processed | 1,293.88 | 1,293.88 | 1,293.88 |
| Networking | Azure DDoS IP Protection | UK South | Protection for 6 resources × 730 hrs | 1,193.99 | 1,193.99 | 1,193.99 |
| Networking | Application Gateway WAF v2 | West Europe | 730 hrs, 1 CU, 1,000 connections, 200 GB transfer | 360.15 | 360.15 | 360.15 |
| Networking | Application Gateway WAF v2 | North Europe | 730 hrs, 1 CU, 1,000 connections, 200 GB transfer | 333.87 | 333.87 | 333.87 |
| Networking | Static IP Addresses | West Europe | 6 static IPs × 730 hrs | 43.80 | 43.80 | 43.80 |
| Networking | Bandwidth | Global | 2,000 GB Internet egress from UK South | 152.00 | 152.00 | 152.00 |
| DevOps | Azure Monitor + Log Analytics | UK South | 1 GB/day analytics logs, 7 dashboards, Application Insights | 90.75 | 90.75 | 90.75 |
| Security | Defender for Cloud CSPM | UK South | 2 billable resources × 730 hrs | 10.22 | 10.22 | 10.22 |
| Security | Defender for Cloud Workload | UK South | 2 App Service nodes, 2 SQL DB servers, 1 subscription | 64.24 | 64.24 | 64.24 |
| Compute | App Service Premium P0v3 | West Europe | 1 × P0v3 (1 vCPU, 4 GB RAM) × 730 hrs, Windows | 123.37 | 92.00 | 74.08 |
| Compute | App Service Premium P0v3 | North Europe | 1 × P0v3 (1 vCPU, 4 GB RAM) × 730 hrs, Windows | 119.72 | 89.83 | 72.25 |
| Databases | Azure SQL GP Gen5 | West Europe | vCore, GP, 4 vCores, 32 GB, Zone Redundant, RA‑GRS backup, DR replica | 1,085.57 | 811.63 | 655.30 |
| Databases | Azure SQL GP Gen5 | North Europe | vCore, GP, 4 vCores, 32 GB, Zone Redundant, RA‑GRS backup, DR replica | 1,027.81 | 773.76 | 628.87 |
|  | **TOTAL** |  |  | **6,931.53** | **6,342.29** | **6,005.56** |

---

## Cost drivers (top 3) — what’s expensive and why

1) **Azure SQL (data layer)** — **$2,113.38/month PAYG combined**  
   - You’re paying for **two regions** (primary + DR replica), **zone redundancy**, and **RA‑GRS** backups.  
   - This is normal for DR-grade data platforms: resiliency costs real money.

2) **Azure Firewall Premium (Hub)** — **$1,293.88/month**  
   - Premium SKU adds **TLS inspection**, **IDPS**, and advanced threat protection features.  
   - If you’re inspecting East‑West flows and enforcing central egress, Firewall becomes a major fixed monthly line item.

3) **Azure DDoS IP Protection** — **$1,193.99/month**  
   - DDoS protection has a **high base cost** because it’s an always‑on managed protection service.  
   - It’s often the first item business owners question — but it can be justified for internet‑facing, revenue workloads.

---

## Cost optimization options (practical)

### 1) Reserved pricing impact (where it matters)
Based on the export totals:

- **PAYG:** $6,931.53/month  
- **1‑Year RI:** $6,342.29/month → **save $589.24/month (~8.5%)**  
- **3‑Year RI:** $6,005.56/month → **save $925.97/month (~13.4%)**

**Why RI savings aren’t huge here:**  
Many networking/security services (Firewall, DDoS, AFD) are mostly fixed monthly charges with limited RI-style savings. The biggest RI wins typically come from **SQL** and **compute** SKUs.

### 2) Right-size App Service deliberately
Start with **Premium v3 P0v3** (as assumed here), then:
- **Scale out** first when CPU/requests increase (more instances).
- **Scale up** only when memory/CPU per instance is the bottleneck.
- Use **autoscale rules** (CPU %, requests, response time) so you don’t pay for peak all month.

This keeps cost elastic while still meeting availability requirements.

### 3) DDoS IP Protection vs DDoS Network Protection (Standard) tradeoff
This estimate uses **DDoS IP Protection** (protect specific public IP resources).  
If you need broader protection scope, consider **DDoS Network Protection (Standard)** which protects an entire VNet, but typically comes with a higher minimum monthly commitment.

**Rule of thumb:**
- **IP Protection**: cost-aware, scoped protection for specific IP resources.
- **Network Protection (Standard)**: stronger “platform guarantee” posture for high-risk production VNets.

---

## Notes and assumptions
- This is a **PAYG estimate snapshot** (pricing date **2026-01-09**).  
- Actuals vary by:
  - traffic (requests, egress, health probes),
  - scaling (App Service / App Gateway capacity),
  - retention (Log Analytics),
  - and Reserved commitment choices.
