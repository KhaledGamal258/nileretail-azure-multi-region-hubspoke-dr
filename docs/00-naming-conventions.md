# Naming conventions

The goal: names that are **human-readable**, **sortable**, and **consistent** across regions.

---

## Format

`<rtype>-<workload>-<env>-<region>-<nn>`

- `rtype`: resource type short code (see table below)
- `workload`: short workload name (`ecom`)
- `env`: `prd` / `tst` / `dev`
- `region`: Azure region short code (`uks`, `neu`, `weu`)
- `nn`: 2-digit sequence

Example: `agw-ecom-prd-neu-01`

---

## Region codes
| Azure region | Code |
|---|---|
| UK South | `uks` |
| North Europe | `neu` |
| West Europe | `weu` |

---

## Resource type codes (suggested)
| Resource | rtype |
|---|---|
| Resource Group | `rg` |
| Virtual Network | `vnet` |
| Subnet | `snet` |
| VPN Gateway | `vpngw` |
| Application Gateway | `agw` |
| App Service | `app` |
| App Service Plan | `asp` |
| Private Endpoint | `pep` |
| Private DNS Zone | `pdns` |
| Log Analytics Workspace | `law` |
| Front Door | `afd` |
| SQL server | `sqlsrv` |
| SQL database | `sqldb` |
| SQL Failover Group | `fog` |
| Azure Firewall | `azfw` |
| Key Vault | `kv` |
| Network Security Group | `nsg` |
| VPN Connection | `con` |

---

## Subnet naming
Use functional names and keep them stable:

- `GatewaySubnet` (must be exact)
- `snet-appgw`
- `snet-appsvc-int`
- `snet-pe`

---

## Tags (minimum)
- `Project = NileRetail-MultiRegion-DR`
- `Environment = prd`
- `Owner = <your-name>`
- `CostCenter = <portfolio>`
- `DataClassification = public|internal|confidential`
