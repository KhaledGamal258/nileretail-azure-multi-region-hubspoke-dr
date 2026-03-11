# Project plan

This document summarizes the delivery plan for the **NileRetail Group — Azure Multi‑Region Production + DR** portfolio engagement.

> **Plan snapshot date:** **2026-01-09** (project artefacts export date)  
> **Timeline year:** 2026 (phases spread across Feb → Dec)  
> **Status:** All phases marked ✅ Done (final state of the portfolio delivery)

---

## Phase summary

| Phase | Name | Target date | Status |
|---:|---|---|---|
| 1 | Pre‑Deployment & Planning | Feb 2026 | ✅ Done |
| 2 | Network Infrastructure Deployment | Jun 2026 | ✅ Done |
| 3 | Application & Data Platform | Sep 2026 | ✅ Done |
| 4 | Security, Monitoring & Operations | Nov 2026 | ✅ Done |
| 5 | Testing, Failover & Go‑Live | Dec 2026 | ✅ Done |

---

## Gantt-style timeline (high level)

| Phase | Feb 2026 | Jun 2026 | Sep 2026 | Nov 2026 | Dec 2026 |
|---|:---:|:---:|:---:|:---:|:---:|
| 1 — Planning | ███ |  |  |  |  |
| 2 — Network |  | ███ |  |  |  |
| 3 — App + Data |  |  | ███ |  |  |
| 4 — SecOps |  |  |  | ███ |  |
| 5 — Go‑Live |  |  |  |  | ███ |

> Legend: **███** = main delivery window for the phase.

---

## Phase 1 — Pre‑Deployment & Planning (Feb 2026) — ✅ Done

**Goal:** Align stakeholders on architecture, security, and cost envelope before any build work.

**Key tasks**
- Architecture design workshop with stakeholders
- Define IP addressing plan and naming conventions
- Design security framework and RBAC model
- Cost estimation using Azure Pricing Calculator
- Budget review and approval

**Target date:** Feb 2026  
**Status:** ✅ Done

---

## Phase 2 — Network Infrastructure Deployment (Jun 2026) — ✅ Done

**Goal:** Establish the Hub & Spoke network foundation with **VNet‑to‑VNet VPN** connectivity and centralized private DNS.

**Key tasks**
- Deploy Hub VNet with VPN Gateway (UK South)
- Deploy Spoke VNets with VPN Gateways (North Europe, West Europe)
- Configure Site‑to‑Site VPN tunnels (Hub ↔ Spokes)
- Deploy Azure Firewall and configure security policies
- Deploy Private DNS Zones and link VNets

**Target date:** Jun 2026  
**Status:** ✅ Done

---

## Phase 3 — Application & Data Platform (Sep 2026) — ✅ Done

**Goal:** Deploy the application platform in both regions and enable cross‑region database DR.

**Key tasks**
- Deploy Azure Front Door with WAF configuration
- Deploy Application Gateways (WAF v2) in both regions
- Deploy App Service Plans and App Services (Premium v3)
- Configure VNet Integration and Private Endpoints
- Deploy Azure SQL Databases in both regions
- Configure Active Geo‑Replication and Failover Groups
- Deploy Azure Key Vaults and migrate secrets

**Target date:** Sep 2026  
**Status:** ✅ Done

---

## Phase 4 — Security, Monitoring & Operations (Nov 2026) — ✅ Done

**Goal:** Add operational visibility (logs/alerts), security posture management, and finalize operational handover.

**Key tasks**
- Deploy Log Analytics Workspace in Hub
- Enable Microsoft Defender for Cloud
- Configure Azure Monitor alerts (performance, availability, security)
- Enable Azure DDoS Protection Standard
- Perform security assessment and remediation
- Documentation and knowledge transfer

**Target date:** Nov 2026  
**Status:** ✅ Done

---

## Phase 5 — Testing, Failover & Go‑Live (Dec 2026) — ✅ Done

**Goal:** Validate the end‑to‑end solution, run DR drills, then cut over to production.

**Key tasks**
- End‑to‑end functional testing
- Performance and load testing
- Failover testing (Azure SQL, Front Door)
- Production cutover and DNS switch

**Target date:** Dec 2026  
**Status:** ✅ Done
