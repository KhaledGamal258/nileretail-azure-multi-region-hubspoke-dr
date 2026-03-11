# NSG rules checklist

> Keep NSGs explicit and minimal. Default-deny is the goal — only allow what is required.

---

## snet-appgw (Application Gateway v2 subnet)

| Priority | Direction | Source                  | Destination | Port(s)      | Action | Why                                    |
|----------|-----------|-------------------------|-------------|--------------|--------|----------------------------------------|
| 100      | Inbound   | `AzureFrontDoor.Backend`| Any         | 443          | Allow  | Traffic from AFD private origin only   |
| 110      | Inbound   | `GatewayManager`        | Any         | 65200–65535  | Allow  | **MANDATORY** — AGW infrastructure health probes. Without this rule, App Gateway v2 will fail to provision and health checks will fail. This is a hard Azure platform requirement. |
| 120      | Inbound   | `AzureLoadBalancer`     | Any         | Any          | Allow  | Azure internal health probes           |
| 200      | Outbound  | Any                     | `snet-pe`   | 443          | Allow  | Backend traffic to App Service PE      |
| 4096     | Inbound   | Any                     | Any         | Any          | Deny   | Default deny all other inbound         |

---

## snet-appsvc-int (App Service VNet Integration subnet)

> This subnet is delegated to `Microsoft.Web/serverFarms`. NSGs apply to outbound traffic
> leaving App Service into the VNet; they do not filter inbound traffic to App Service.

| Priority | Direction | Source | Destination          | Port(s) | Action | Why                                    |
|----------|-----------|--------|----------------------|---------|--------|----------------------------------------|
| 100      | Outbound  | Any    | `snet-pe`            | 1433    | Allow  | App → SQL Private Endpoint             |
| 110      | Outbound  | Any    | `snet-pe`            | 443     | Allow  | App → App Service Private Endpoint (if calling another App Service privately) |
| 200      | Outbound  | Any    | `AzureMonitor`       | 443     | Allow  | App Service diagnostic logs / metrics  |
| 210      | Outbound  | Any    | `Storage`            | 443     | Allow  | App Service content storage (required for some SKUs) |
| 4096     | Outbound  | Any    | Any                  | Any     | Deny   | Deny all other outbound                |

---

## snet-pe (Private Endpoints subnet)

| Priority | Direction | Source              | Destination | Port(s) | Action | Why                                    |
|----------|-----------|---------------------|-------------|---------|--------|----------------------------------------|
| 100      | Inbound   | `snet-appsvc-int`   | Any         | 1433    | Allow  | App Service → SQL PE                   |
| 110      | Inbound   | `snet-appgw`        | Any         | 443     | Allow  | App Gateway → App Service PE           |
| 4096     | Inbound   | Any                 | Any         | Any     | Deny   | Deny all other inbound                 |

> **Note on PE subnet NSG enforcement:**
> As of 2023, Azure supports NSG enforcement on Private Endpoint subnets when
> `privateEndpointNetworkPolicies` is set to `Enabled` (or `NetworkSecurityGroupEnabled`).
> The current Bicep uses `Disabled` (legacy/widest compatibility). To enable NSG enforcement,
> update the subnet property and ensure the rules above are in place first.

---

## GatewaySubnet (VPN Gateway subnet)

**Do NOT attach an NSG to the GatewaySubnet.** Azure will reject VPN Gateway
deployments if an NSG is present on this subnet. This is a platform-level restriction.

---

## Common mistakes

- Missing the `GatewayManager` 65200–65535 rule on `snet-appgw` → App Gateway fails to provision
- Attaching an NSG to `GatewaySubnet` → VPN Gateway deployment is rejected
- Attaching a UDR to `GatewaySubnet` → asymmetric routing breaks VPN tunnels
