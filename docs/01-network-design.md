# Network design (LLD)

---

## Topology

- **Hub VNet (UK South):** centralised connectivity, Private DNS zones, DNS resolver (future), VPN Gateway.
- **Spoke-A (North Europe):** application + data tier (Primary).
- **Spoke-B (West Europe):** application + data tier (Secondary / DR).

---

## Addressing plan

| VNet                   | Region        | CIDR           |
|------------------------|---------------|----------------|
| `vnet-hub-uks-prd`     | UK South      | `10.10.0.0/16` |
| `vnet-ecom-prd-neu-01` | North Europe  | `10.11.0.0/16` |
| `vnet-ecom-prd-weu-01` | West Europe   | `10.12.0.0/16` |

> Adjust CIDRs to your org IPAM. Reserve gaps between spokes for future expansion.

---

## Hub subnets

| Subnet          | CIDR             | Purpose                              | Notes                                                    |
|-----------------|------------------|--------------------------------------|----------------------------------------------------------|
| `GatewaySubnet` | `10.10.0.0/27`   | VPN Gateway                          | **Name must be exactly `GatewaySubnet`.** No NSG, No UDR. |
| `snet-pe`       | `10.10.1.0/24`   | Private Endpoints (hub-level)        | For centralised PE pattern.                              |
| `snet-dns`      | `10.10.2.0/24`   | Azure DNS Private Resolver (future)  | Minimum /28; reserve /24 for resolver endpoints.        |

---

## Spoke subnets (each spoke)

| Subnet            | CIDR (Spoke-A)   | CIDR (Spoke-B)   | Purpose                              | Notes                                                    |
|-------------------|------------------|------------------|--------------------------------------|----------------------------------------------------------|
| `snet-appgw`      | `10.11.0.0/24`   | `10.12.0.0/24`   | Application Gateway v2               | Dedicated subnet required. /24 gives autoscale headroom. **NSG must allow 65200-65535 from GatewayManager.** |
| `snet-appsvc-int` | `10.11.1.0/24`   | `10.12.1.0/24`   | App Service VNet Integration         | **Must be delegated to `Microsoft.Web/serverFarms`.** /24 gives ~250 IPs for autoscale + slots. |
| `snet-pe`         | `10.11.2.0/24`   | `10.12.2.0/24`   | Private Endpoints (SQL, App Service) | One PE per server/service. /24 is comfortable for this design. |
| `GatewaySubnet`   | `10.11.254.0/27` | `10.12.254.0/27` | Spoke VPN Gateway                    | Placed at the end of the /16 to leave middle space for future subnets. **No NSG, No UDR.** |

---

## Connectivity

- **VNet-to-VNet VPN** between Hub ↔ Spoke-A and Hub ↔ Spoke-B.
- Each pair requires **two Connection resources** (one per gateway, same shared key).
- Spokes are isolated from each other — spoke-to-spoke traffic would route Hub → Spoke (not implemented in this design).

---

## DNS & Private Link

**Private DNS Zones (centralised in hub RG):**

| Zone                                | Covers                          |
|-------------------------------------|---------------------------------|
| `privatelink.azurewebsites.net`     | App Service Private Endpoints   |
| `privatelink.database.windows.net`  | Azure SQL Private Endpoints     |

- Zones are linked to Hub + both Spoke VNets via `private-dns.bicep`.
- DNS Zone Groups on each Private Endpoint auto-manage A records — never create A records manually.
- All three VNets resolve Private Endpoint FQDNs via the hub-linked zones.

---

## NSGs

Subnet-level NSGs are required on all subnets except `GatewaySubnet`.
See [`docs/checklists/nsg-rules.md`](../checklists/nsg-rules.md) for the full port matrix.

Key rules:
- `snet-appgw`: inbound 65200–65535 from `GatewayManager` is **mandatory** for App Gateway v2.
- `snet-appsvc-int`: outbound to `snet-pe` only.
- `snet-pe`: inbound from `snet-appsvc-int` and `snet-appgw` only.
- `GatewaySubnet`: **no NSG** — Azure rejects VPN Gateway deployments if one is attached.
