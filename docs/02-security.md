# Security design

This document describes the security controls applied to the NileRetail platform and the reasoning behind each decision.

---

## Identity — Microsoft Entra ID

**What is configured:**
- MFA + Conditional Access policies for all admin roles
- Least-privilege RBAC assignments (no standing Owner/Contributor for engineers)
- Privileged Identity Management (PIM) for just-in-time privileged access
- Managed Identities for App Service — the application connects to Azure SQL and Key Vault without storing any credentials

**Why it matters:**
Identity is the primary attack vector for cloud breaches. Managed Identities eliminate the entire class of credential-leakage vulnerabilities (no passwords in config files, no connection strings with hardcoded credentials). Conditional Access ensures that even if credentials are compromised, access requires a trusted device from a trusted location.

---

## Edge protection — Azure Front Door WAF

**What is configured:**
- WAF Policy in **Prevention mode** (not Detection) — threats are blocked, not just logged
- OWASP DefaultRuleSet 2.1 — covers OWASP Top 10 including SQL injection, XSS, path traversal
- Microsoft Bot Manager 1.1 — blocks known bad bots and credential stuffing tools
- TLS 1.2 minimum enforced end-to-end

**Why Prevention mode from day one:**
Detection mode logs threats but takes no action. Running Detection in production means your application is being attacked but not protected. For an e-commerce platform handling payments and user data, Prevention mode is the only appropriate choice.

**Why both Front Door WAF and Application Gateway WAF:**
This is defence-in-depth. Front Door WAF stops threats at the edge before they reach the region. Application Gateway WAF provides a second inspection layer for any traffic that reaches the regional ingress. Two independent WAF layers means an attacker must bypass both independently.

---

## DDoS protection — IP Protection (not Network Protection)

**What is configured:**
- Azure DDoS IP Protection on the critical public IP resources: VPN Gateway IPs and any intentionally public ingress IPs

**Why IP Protection instead of Network Protection (Standard):**
Azure DDoS Network Protection (Standard) protects an entire VNet and carries a high flat monthly fee (~$2,944/month base). DDoS IP Protection protects specific public IP resources at a per-resource cost — significantly cheaper for a design where only a small number of IPs are intentionally public.

For this architecture, the public IPs that need DDoS protection are well-defined: the VPN Gateway public IPs. App Service and SQL are fully private (no public IPs). Application Gateway fronts private traffic via Private Link from Front Door. IP Protection is both sufficient and cost-optimal.

**Cost impact:** Network Protection would add ~$2,944/month. IP Protection for 6 resources costs ~$1,194/month — a $1,750/month saving with equivalent protection for the actual public IP surface.

---

## Private connectivity — Private Endpoints

**What is configured:**
- Azure SQL: public network access **disabled**; accessible only via Private Endpoint in `snet-pe`
- App Service: public access **disabled**; accessible only via Private Endpoint in `snet-pe`
- Private DNS zones auto-manage DNS A records via DNS Zone Groups — no manual records

**Why Private Endpoints instead of Service Endpoints:**
Service Endpoints allow traffic from a subnet to a PaaS service but the traffic still traverses the public Azure backbone and the service is still reachable from other networks. Private Endpoints place a private NIC with a private IP inside your VNet — the service is only reachable via that IP, and public access can be completely disabled. For GDPR and zero-trust compliance, Private Endpoints are the correct choice.

**Why DNS Zone Groups (not manual A records):**
DNS Zone Groups automatically create and maintain the A records in the Private DNS zone when a Private Endpoint is provisioned or reprovisioned. Manual A records break silently when IPs change. Zone Groups are self-healing.

---

## Microsoft Defender for Cloud

**What it is:**
**Microsoft Defender for Cloud** is a Cloud Security Posture Management (CSPM) and Cloud Workload Protection Platform (CWPP). It continuously monitors the Azure environment for misconfigurations, vulnerabilities, and active threats.

**What is enabled in this project:**

| Plan | What it protects | What it detects |
|------|-----------------|-----------------|
| Defender CSPM | Entire subscription | Misconfigurations, insecure defaults, deviations from security benchmarks. Produces a Secure Score. |
| Defender for App Service | App Service plans (NEU + WEU) | Suspicious process execution, communication with known malicious IPs, unusual access patterns |
| Defender for Azure SQL | SQL servers (NEU + WEU) | SQL injection attempts, anomalous access, unusual query patterns, brute-force login attempts |

**Why it matters for e-commerce:**
Defender for SQL specifically detects SQL injection at the database layer — the most common attack against e-commerce platforms. Even with WAF at the edge, defence-in-depth means you want anomaly detection at the data tier as well. The Secure Score gives a continuous, prioritised remediation list rather than a one-time point-in-time assessment.

---

## Secrets management — Azure Key Vault

**What is configured:**
- All secrets (SQL admin credentials, API keys, JWT signing keys, SSL certificates) stored in Key Vault
- App Service accesses Key Vault via Managed Identity — no secrets in application config
- Key Vault access policies follow least-privilege

**Why:**
Secrets in environment variables or application settings are exposed in deployment pipelines, logs, and source control accidents. Key Vault with Managed Identity eliminates this: the application gets a token from Azure AD at runtime, not a stored secret.
