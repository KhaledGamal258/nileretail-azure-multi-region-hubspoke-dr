# Scripts

---

## validate-dns.sh

**Purpose:** Validates that Private DNS resolution and TCP connectivity are working correctly for all Private Endpoint-connected services — Azure SQL (Failover Group listener) and App Service — from inside the VNet.

**When to run:** After completing the deployment (Phases 1–4 of the implementation guide) and before going live.

**Where to run:** From a Linux VM deployed inside the Hub VNet or either Spoke VNet, with line-of-sight to the private endpoints. Alternatively, use the App Service Kudu console (Tools → Debug console → Bash).

**Requirements:**
- Azure CLI (`az`) logged in with access to the subscription
- `dig` or `nslookup` (DNS check — script auto-detects which is available)
- `nc` / netcat (TCP connectivity check — optional but recommended)
- `curl` (HTTP probe — optional but recommended)

---

## What it checks

| Check | What it validates |
|-------|-----------------|
| SQL Failover Group DNS | `fog-ecom-prd-01.database.windows.net` resolves to a **private IP** (10.x.x.x), not a public Azure IP |
| SQL TCP connectivity | TCP port 1433 is reachable on the resolved private IP |
| App Service DNS (NEU) | `app-ecom-prd-neu-01.azurewebsites.net` resolves to a private IP |
| App Service DNS (WEU) | `app-ecom-prd-weu-01.azurewebsites.net` resolves to a private IP |
| App Service SCM DNS | `.scm.azurewebsites.net` endpoints resolve to private IPs (Kudu access) |
| App Gateway health probe | HTTP probe to `GET /health` on the Application Gateway frontend IP returns a response |

---

## Usage

```bash
chmod +x scripts/validate-dns.sh

# Run with defaults (uses naming convention to auto-discover resources)
./scripts/validate-dns.sh

# Override resource names if your naming differs
WORKLOAD=ecom ENV=prd \
RG_NEU=rg-ecom-prd-neu-spoke \
RG_WEU=rg-ecom-prd-weu-spoke \
./scripts/validate-dns.sh
```

---

## Interpreting results

- **SQL resolves to a public IP** (e.g. `13.x.x.x`): the Private DNS zone is not linked to this VNet — re-run `private-dns.bicep` and ensure the VNet ID is passed correctly.
- **TCP 1433 fails after DNS resolves correctly**: check the `snet-pe` NSG — inbound 1433 from `snet-appsvc-int` must be allowed.
- **App Service resolves to a public IP**: the Private Endpoint DNS Zone Group may be missing — check with `az network private-endpoint dns-zone-group list`.
- **App Gateway probe returns no response**: the `GatewayManager` inbound rule (ports 65200–65535) may be missing from the `snet-appgw` NSG — see [`docs/checklists/nsg-rules.md`](../docs/checklists/nsg-rules.md).

See [`docs/runbooks/dns-troubleshooting.md`](../docs/runbooks/dns-troubleshooting.md) for the full step-by-step troubleshooting procedure.
