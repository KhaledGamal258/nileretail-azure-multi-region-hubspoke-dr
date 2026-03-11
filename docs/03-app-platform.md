# Application platform

---

## Ingress architecture — defence-in-depth
```
Internet → Azure Front Door Premium (WAF + Global routing)
         → Private Link
         → Application Gateway v2 (WAF + Regional LB)
         → App Service (Premium v3, VNet-integrated)
         → Private Endpoint
         → Azure SQL (Failover Group)
```

This is a three-layer ingress model. Each layer provides independent WAF inspection, load balancing, and health checking. No single component failure takes down the platform.

---

## Azure Application Gateway v2

**Configuration:**
- WAF_v2 tier with OWASP rule set enabled
- Zone-redundant deployment (instances spread across 3 availability zones)
- Health probes to App Service private endpoints
- SSL offloading at the gateway

**Why Application Gateway and not just Front Door:**
**Azure Front Door Premium** operates at the edge (globally distributed PoPs). **Azure Application Gateway v2** operates regionally inside the VNet. Together they provide edge security + regional load balancing with VNet-native private connectivity to App Service. Application Gateway can reach App Service via its Private Endpoint — Front Door cannot do this directly without Application Gateway as the bridge.

---

## Azure App Service — Premium v3

**Why Premium v3:**
- VNet Integration is only available on Standard tier and above, but **zone redundancy requires Premium v3**
- P0v3 (1 vCPU, 4 GB RAM) is the entry-point SKU — sufficient for initial traffic; scale up to P1v3/P2v3 as workload grows
- Deployment slots (staging/production) enable zero-downtime deployments with blue-green swap

**VNet Integration — why it is mandatory:**
Without VNet Integration, App Service outbound traffic goes via the public internet. With VNet Integration into `snet-appsvc-int`, all outbound traffic from the app (to SQL, to Key Vault, to any backend) stays inside the VNet fabric and is routed through the Hub. This is what makes the Private Endpoint connectivity to SQL work — the app reaches the SQL Private Endpoint via the VNet, not the internet.

**Security — public access disabled:**
App Service `publicNetworkAccess` is set to `Disabled`. The only way to reach the application is via the Application Gateway's Private Endpoint. There is no direct HTTP/HTTPS endpoint exposed to the internet.

---

## Origin access model
```
Azure Front Door
  └─ Private Link connection (groupId: appGatewayFrontendIp)
       └─ Application Gateway (private, no direct public exposure)
            └─ App Service (via Private Endpoint in snet-pe)
```

The Application Gateway's frontend IP is the Private Link target for Front Door. This means:
- Front Door reaches the origin through Azure's private backbone
- The Application Gateway never needs a public IP to serve Front Door traffic
- An attacker cannot reach the Application Gateway directly from the internet

---

## Deployment model

- **Deployment slots:** staging slot for pre-production testing; swap to production for zero-downtime release
- **Autoscale rules:** scale out on CPU > 70% or HTTP queue depth > 100; scale in after 10 minutes of low utilisation
- **Centralised logging:** all App Service diagnostic logs, HTTP access logs, and application logs stream to `log-ecom-prd-uks-01` Log Analytics Workspace
