# ADR 0001 — Azure Front Door Premium with Private Link origin

---

## Status
Accepted

---

## Context
NileRetail's application must be globally accessible but the origin (Application Gateway + App Service) must never be directly reachable from the public internet. Two Front Door origin models were evaluated: public origin and Private Link origin.

---

## Decision
Use **Azure Front Door Premium** with **Private Link** to connect to regional Application Gateways as private origins.

---

## Rationale

### Origin never exposed to the internet
With a public origin, any attacker who discovers the Application Gateway's public IP can bypass Front Door entirely — bypassing the WAF and DDoS protection. Private Link origin means the Application Gateway has no public IP path that Front Door uses; the connection is made through Azure's private backbone. The Application Gateway's public IP can be locked down to allow only Azure Front Door service tags.

### WAF at the edge, not just at the region
Front Door Premium's WAF runs at Microsoft's global edge PoPs — threats are blocked before they reach the Azure region. This is significantly more efficient than running WAF only at the regional Application Gateway, because malicious traffic never consumes regional bandwidth or compute.

### Automatic failover across regions
Front Door's origin group (primary: North Europe, secondary: West Europe) provides automatic failover with health probes. If the North Europe Application Gateway becomes unhealthy, Front Door routes all traffic to West Europe without DNS TTL delays or manual intervention. This directly supports the RTO requirement for an always-on e-commerce platform.

### GDPR and data residency
By controlling origin selection at the Front Door layer, traffic from European users is always routed to EU regions (NEU or WEU). This is important for GDPR data residency obligations — customer request data stays in EU Azure regions.

---

## Trade-offs accepted
- After deployment, the Private Link connection on each Application Gateway must be **manually approved** (or automated via CLI). This is a one-time step but adds operational complexity.
- Front Door Premium SKU has a higher base cost than Standard. Justified by WAF, Private Link, and advanced routing capabilities required for this design.
