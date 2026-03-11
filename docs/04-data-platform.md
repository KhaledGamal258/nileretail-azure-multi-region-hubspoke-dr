# Data platform

---

## Architecture overview
```
App Service (NEU) ──→ Private Endpoint (snet-pe NEU) ──→ sqlsrv-ecom-prd-neu-01 [PRIMARY]
                                                                   │
                                                         Auto-Failover Group
                                                         fog-ecom-prd-01
                                                                   │
App Service (WEU) ──→ Private Endpoint (snet-pe WEU) ──→ sqlsrv-ecom-prd-weu-01 [SECONDARY]
```

Applications connect exclusively via the **Failover Group listener FQDN**: `fog-ecom-prd-01.database.windows.net`

---

## Azure SQL Auto-Failover Group — why, not just what

**What geo-replication alone gives you:**
Active geo-replication continuously replicates the primary database to the secondary region (async replication, typically <5 seconds lag). You get a readable secondary for offloading read queries.

**What the Failover Group adds on top:**
The **Failover Group** wraps geo-replication with a **single listener endpoint** that always points to the current primary. When failover happens (manual or automatic), the listener FQDN automatically resolves to the new primary — no application code changes, no connection string updates, no DNS TTL wait.

Without a Failover Group: your app must detect the failover, update its connection string, and reconnect. This is error-prone and slow.
With a Failover Group: failover is transparent to the application.

---

## Failover configuration

| Setting | Value | Reason |
|---------|-------|--------|
| Failover policy | Manual (default) | Prevents automatic failover on transient regional issues. Requires engineer decision. Reduces risk of unnecessary failover. |
| Grace period | 60 minutes (if Automatic) | Ensures a genuine regional outage, not a blip, triggers automatic failover. |
| Read-only endpoint | Enabled | `fog-ecom-prd-01.secondary.database.windows.net` available for reporting/analytics queries on the secondary — offloads read traffic from primary. |

---

## RPO and RTO

| Metric | Target | How it is achieved |
|--------|--------|--------------------|
| RPO (data loss) | < 5 seconds | Async geo-replication lag is typically < 5 seconds under normal conditions |
| RTO (recovery time) | < 5 minutes | Manual failover via `az sql failover-group set-primary` completes in 20–30 seconds; listener DNS update propagates within seconds |

---

## Networking — why Private Endpoints are required

**Azure SQL** is a PaaS service — it does not live inside your VNet. Without Private Endpoints, your App Service would connect to `*.database.windows.net` over the public internet. With Private Endpoints:

- A private NIC with a private IP (e.g. `10.11.2.5`) is placed inside `snet-pe`
- `sqlsrv-ecom-prd-neu-01.database.windows.net` resolves to `10.11.2.5` (via Private DNS Zone Group)
- All SQL traffic stays inside the VNet — never touches the internet
- `publicNetworkAccess` on both SQL servers is set to `Disabled` — direct internet connections are rejected even if attempted

---

## Zone redundancy

Both SQL servers are deployed with **zone-redundant** configuration. This means:
- Within each region, the database has 3 replicas spread across 3 availability zones
- If one availability zone (datacenter) fails, the database fails over locally within seconds — completely transparent to the application
- Zone redundancy + Failover Group = protection against both zone failure (local) and regional failure (cross-region)

---

## Connection string — critical rule
```
✅ CORRECT — use the Failover Group listener:
Server=tcp:fog-ecom-prd-01.database.windows.net,1433;Database=appdb;

❌ WRONG — pins the app to one region:
Server=tcp:sqlsrv-ecom-prd-neu-01.database.windows.net,1433;Database=appdb;
```

If the application uses the individual server FQDN, failover to the secondary breaks the connection because the FQDN still points to the original (now failed) region.
