# Assumptions & scope boundaries

---

## Scenario summary
An e-commerce company with a mobile/web application expands into Europe and requires:
- Hub & Spoke topology
- Multi-region availability (Primary + DR)
- Private connectivity via Private Link / Private Endpoints
- VPN S2S “instead of peering”
- Robust security controls (WAF, DDoS, Defender, identity)

---

## In-scope
- Architecture (HLD + LLD)
- Networking & DNS design
- Security controls at a design level
- DR strategy for the data tier
- Monitoring and operational runbooks
- High-level implementation guide

---

## Out-of-scope (for this portfolio version)
- Application code, CI/CD pipelines, and runtime configuration (infrastructure is fully implemented; app layer is out of scope for this portfolio)
- Detailed perf testing results
