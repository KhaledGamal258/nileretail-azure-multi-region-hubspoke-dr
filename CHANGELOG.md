# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [1.2.6] — 2026-03-11

### Fixed
- **diagrams/LLD.drawio**: Aligned all resource names to project naming convention (`<rtype>-ecom-prd-<region>-<nn>`) — 21 labels corrected: added missing `ecom` workload segment, fixed SQL rtype (`sql` → `sqlsrv`), corrected PE names. Subnet labels updated to match implementation (`AppGatewaySubnet` → `snet-appgw`, `AppServiceIntegrationSubnet` → `snet-appsvc-int`, `PrivateEndpointSubnet` → `snet-pe`). Fixed spacing inconsistency in region label (`SPOKE - A` → `SPOKE-A`).
- **diagrams/LLD.drawio** (line styles): Fixed 10 edge style issues — all `strokeWidth=1` edges corrected to `strokeWidth=2` for consistency; SQL geo-replication edge changed from solid to dash-dot (`dashPattern=8 4 1 4`) to indicate async replication; VPN Hub↔Spoke connections changed from dotted (`1 4`) to dashed (`8 8`) to match HLD convention and distinguish VPN tunnels from DNS lines; Private Link (AFD→AGW) arrow direction corrected from reversed (`classicThin→none`) to forward (`none→classic`).
- **diagrams/HLD.drawio**: Updated VNet labels to match project naming convention. Fixed one `strokeWidth=1` edge to `strokeWidth=2`.
- **README.md + README.ar.md**: Added internship attribution note — clarifies the project was built during a Cloud Engineer Internship at GBG, Egypt, and that GBG is not the owner (personal portfolio work, fictional client, no proprietary data).
- **README.md**: Replaced inline internship quote with a proper `## Project context` section — clearly states GBG internship graduation project, NileRetail is fictional, personal portfolio work, no GBG proprietary data. Cleaned up `## Disclaimer` to reference Project context instead of duplicating it.
- **README.ar.md**: Updated VPN S2S bullet from "as per scenario requirements" to the real technical reasons — IPSec/IKEv2 encryption, centralised Hub routing, on-premises readiness.
- **diagrams/HLD.drawio + LLD.drawio**: Fixed connection line styles — 9 edges corrected:
  - HLD: AGW WEU → App Service WEU stroke weight w=1 → w=2 (now consistent with SPOKE-A equivalent); SQL Primary → SQL Secondary changed from solid to dashed (dp=8 4 1 4) to correctly represent async geo-replication, not live traffic.
  - LLD: 6 data-path edges (AFD → Private Link → AGW → App Service in both regions) promoted from w=1 → w=2; SQL NEU → SQL WEU changed from solid w=1 to dashed w=2 dp=8 4 1 4.

---

## [1.2.5] — 2026-03-11

### Changed
- **Markdown consistency pass across the repository**: Added missing `---` separators before every `##` section in project documentation and folder READMEs for consistent GitHub rendering.
- **Folder README headings**: Standardised remaining title-style headings to sentence case in `cost/README.md`, `project-plan/README.md`, `presentation/README.md`, and `sow/README.md`.

### Notes
- No architecture, costing, or IaC logic changed in this version. This is a presentation and consistency polish release on top of the completed `v1.2.4` content baseline.

---

## [1.2.4] — 2026-03-10

### Fixed
- **iac/bicep/README.md**: Replaced “starter scaffold” placeholder with accurate module documentation — module overview table, supporting modules table, deployment order, key design notes (parent syntax, cross-RG scope, VPN Connection pairing, Private Link approval, GatewaySubnet restriction).
- **scripts/README.md**: Replaced 2-line placeholder with full script documentation — what `validate-dns.sh` checks (6 checks listed), how to run it, environment variable overrides, how to interpret each failure mode.
- **docs/checklists/nsg-rules.md**: Corrected H1 capitalisation — `# NSG Rules Checklist` → `# NSG rules checklist`.
- **docs/00-naming-conventions.md**: Added 5 missing resource type codes used in the Bicep modules: `fog` (SQL Failover Group), `azfw` (Azure Firewall), `kv` (Key Vault), `nsg` (Network Security Group), `con` (VPN Connection).

### Changed
- **README.md** — “What this repo showcases”: Removed “requirement-driven” label from VPN S2S bullet; replaced with the actual technical reasons (IPSec/IKEv2 encryption, transitive routing, on-premises readiness).
- **README.md** — “Key design decisions”: Completely rewritten. Each decision now explains the real technical reasoning — VPN encryption standard, Private Link origin attack surface, Private Endpoint GDPR compliance, DDoS IP vs Network Protection cost saving ($1,750/month), Failover Group listener FQDN benefit, Defender for Cloud CSPM + workload protection. Each subsection links to its full document.

---

## [1.2.3] — 2026-03-10

### Changed (content enrichment)

- **docs/adr/0002-vpn-vnet2vnet-instead-of-peering.md**: Replaced 3-bullet placeholder with full ADR — IPSec encryption rationale, routing control justification, on-premises readiness, trade-off comparison table.
- **docs/adr/0001-private-origin-frontdoor.md**: Replaced 3-bullet placeholder with full ADR — origin exposure risk, edge WAF rationale, GDPR data residency, Private Link trade-offs.
- **docs/02-security.md**: Replaced skeleton with full explanations — WHY DDoS IP Protection (cost reasoning, $1,750/month saving vs Network Protection), WHY Private Endpoints over Service Endpoints, Defender for Cloud explained with plan table (CSPM + App Service + SQL workload protection).
- **docs/03-app-platform.md**: Replaced skeleton with full architecture — ingress flow diagram, WHY Application Gateway + Front Door together, WHY Premium v3, WHY VNet Integration is mandatory for private SQL connectivity.
- **docs/04-data-platform.md**: Replaced skeleton with full data platform doc — WHY Failover Group vs geo-replication alone, RPO/RTO table, zone redundancy explanation, Private Endpoint networking diagram, connection string rule.

---

## [1.2.2] — 2026-03-10

### Changed (formatting & presentation)
- **All docs**: Standardised all H1/H2 headings to Sentence case for consistent presentation throughout the documentation set.
- **README.md**: Added missing `---` horizontal separators above every `##` section for consistent visual rhythm on GitHub.
- **README.md**: Improved image alt text — `![HLD]` → `![High-Level Design — NileRetail Azure Hub & Spoke]` for accessibility and professionalism.
- **docs/99-references.md**: Converted all bare URLs to `[descriptive text](url)` hyperlinks. Added three missing sections: VPN Gateway, Bicep child resources, Bicep modules.
- **docs/02-security.md**, **03-app-platform.md**, **04-data-platform.md**: Added `---` section separators to match the rest of the documentation set.

---

## [1.2.1] — 2026-03-10

### Fixed

- **docs/05-operations.md**: Replaced 12-line skeleton with full operations document — KQL queries, alert rules with CLI commands, dashboard definitions.
- **docs/runbooks/dr-failover.md**: Replaced 5-bullet skeleton with real runbook — trigger criteria, CLI failover and failback commands, validation steps, communication template.
- **docs/runbooks/dns-troubleshooting.md**: Replaced checklist with step-by-step troubleshooting procedure — `az` CLI commands, `nslookup` validation, TCP connectivity tests, common failure modes table.
- **docs/00-assumptions.md**: Removed contradictory "IaC scaffold" statement — IaC is fully implemented; updated out-of-scope to reflect actual project state.
- **sql-failover-group.bicep**: Removed duplicate comment blocks left from earlier edit pass.

---

## [1.2.0] — 2026-03-09

### Fixed

- **frontdoor-private-origin.bicep**: Child resources used slash-delimited names instead of `parent:` — Bicep compilation error. Fixed all six child resources to use `parent:` syntax.
- **sql-failover-group.bicep**: `primaryDb` and `failoverGroup` used slash-delimited names instead of `parent:` — Bicep compilation error. Fixed both to use `parent: primarySql`.

### Added

- **cost/** folder with README.md referencing the Azure cost estimate workbook.
- **project-plan/** folder with README.md referencing the project plan workbook.
- **presentation/** folder with README.md referencing the walk-through deck.
- **sow/** folder with README.md referencing the Scope of Work document, including a note on the CIDR discrepancy between SOW and implementation.
- **docs/06-costing.md**: Filled with real cost data — full service breakdown, totals for PAYG/1-year RI/3-year RI, cost drivers analysis, and optimization options.
- **docs/07-project-plan.md**: Filled with real 5-phase plan — tasks, dates, status, and Gantt-style summary table.

---

## [1.1.0] — 2026-03-09

### Fixed
- **hub.bicep**: Tags `param` default referenced other params — Bicep compilation error. Moved to `var defaultTags`.
- **hub.bicep**: `union()` used for `ipConfigurations` array concatenation — replaced with `concat()` (semantically correct; `union()` deduplicates).
- **private-dns.bicep**: `param vnetLinkNamePrefix` default interpolated other params — Bicep compilation error. Moved to `var vnetLinkNamePrefix`.
- **08-implementation-guide.md**: VPN connection CLI commands used gateway names for `--vnet-gateway2` across resource groups. Cross-RG lookups require full resource IDs — fixed all four connection commands.
- **08-implementation-guide.md**: Used deprecated `--disable-private-endpoint-network-policies true` flag. Replaced with `--private-endpoint-network-policies Disabled`.
- **08-implementation-guide.md**: `vnetIds` array parameter passed with unquoted string values containing slashes. Fixed to use properly JSON-escaped string array syntax.
- **08-implementation-guide.md**: Spoke subnet names used PascalCase (`AppGatewaySubnet`) inconsistent with project naming convention. Aligned to `snet-appgw`, `snet-appsvc-int`, `snet-pe`.
- **docs/01-network-design.md**: Subnet table updated to match implementation guide naming convention.
- **docs/checklists/nsg-rules.md**: Added mandatory App Gateway v2 rule — inbound 65200–65535 from `GatewayManager`. Without this rule, AGW fails to provision.

### Added
- **spoke.bicep**: Full implementation — VNet + four subnets (with delegation on `snet-appsvc-int`) + VPN Gateway + outputs.
- **sql-failover-group.bicep**: Full implementation — primary/secondary SQL servers, database, auto-failover group, private endpoints with DNS zone groups.
- **frontdoor-private-origin.bicep**: Full implementation — AFD Premium, WAF policy (Prevention mode, OWASP 2.1, Bot Manager 1.1), origin group, Private Link origins, routing rule.

---

## [1.0.0] — 2026-03-07

### Added
- Initial repo scaffold: HLD/LLD diagrams, full documentation set (network, security, app, data, operations, costing, project plan, implementation guide).
- `hub.bicep`: Hub VNet + VPN Gateway (active-active capable).
- `private-dns.bicep`: Private DNS zones + VNet links for all three VNets.
- `vnet2vnet-connection.bicep`: Reusable module for one side of a VNet-to-VNet connection.
- `validate-dns.sh`: DNS and connectivity validation script.
- ADRs: Front Door private origin, VPN over peering.
- Runbooks: DR failover, DNS troubleshooting.
- `.gitignore`, `CONTRIBUTING.md`, `SECURITY.md`, `LICENSE`.
