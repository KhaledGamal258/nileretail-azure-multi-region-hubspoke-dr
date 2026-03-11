# Runbook — DR failover

---

## Purpose
This runbook covers **manual failover** of the NileRetail production data tier from:
- **Primary region:** North Europe
- **Secondary region:** West Europe

This runbook is used when the primary region is unavailable long enough that a controlled failover is safer than waiting for recovery.

---

## Trigger criteria
Initiate failover only when **all** of the following are true:
1. **Primary region is down or materially degraded for more than 15 minutes**
2. The event is **confirmed**, not just a brief monitoring blip or probe anomaly
3. The issue materially affects customer traffic, database availability, or ingress health
4. The **secondary region has been verified healthy** and capable of handling production traffic

---

## Decision authority
- **On-call engineer:** confirms impact, gathers evidence, validates secondary health
- **Tech Lead:** approves failover execution
- If the Tech Lead is unavailable, use the agreed incident escalation chain

---

## Pre-failover checks
Before changing primary:
1. Confirm Front Door and App Gateway in West Europe are healthy
2. Confirm `sqlsrv-ecom-prd-weu-01` is reachable through its Private Endpoint
3. Confirm the failover group exists and current role is as expected
4. Confirm no platform freeze / maintenance activity is already in progress
5. Confirm application owners are aware of the cutover window

---

## Step-by-step procedure

### 1) Check the current failover-group role
```bash
az sql failover-group show \
  -g rg-ecom-prd-neu-spoke \
  -s sqlsrv-ecom-prd-neu-01 \
  -n fog-ecom-prd-01 \
  --query replicationRole -o tsv
```

Expected result before failover:
- `Primary` in North Europe
- `Secondary` in West Europe

### 2) Initiate manual failover to the secondary
```bash
az sql failover-group set-primary \
  -g rg-ecom-prd-weu-spoke \
  -s sqlsrv-ecom-prd-weu-01 \
  -n fog-ecom-prd-01
```

> This promotes the West Europe server to the new primary for the failover group.

### 3) Re-check the failover-group role
```bash
az sql failover-group show \
  -g rg-ecom-prd-weu-spoke \
  -s sqlsrv-ecom-prd-weu-01 \
  -n fog-ecom-prd-01 \
  --query replicationRole -o tsv
```

Expected result after failover:
- `Primary` in West Europe

---

## Validation steps

### 1) Validate listener DNS resolution
From inside the VNet (Kudu console or test VM), verify the listener resolves correctly:
```bash
nslookup fog-ecom-prd-01.database.windows.net
```

Expected:
- Resolves to the **private IP** of the new primary server's Private Endpoint
- Must **not** resolve to a public Azure SQL IP

### 2) Validate application health
Check the Front Door health probe endpoint or the application health endpoint:
```bash
curl -I https://<your-frontdoor-endpoint>/health
```

Expected:
- `HTTP/1.1 200 OK`

### 3) Validate synthetic app connectivity
From App Service Kudu or a test VM:
```bash
tcpping fog-ecom-prd-01.database.windows.net:1433
```

Expected:
- TCP connect succeeds

---

## Failback procedure
Fail back only after:
1. North Europe is confirmed stable
2. Data synchronization lag is acceptable
3. The incident commander / Tech Lead approves failback

Run the same command in reverse:
```bash
az sql failover-group set-primary \
  -g rg-ecom-prd-neu-spoke \
  -s sqlsrv-ecom-prd-neu-01 \
  -n fog-ecom-prd-01
```

Then repeat the same validation steps:
- listener DNS resolution
- app health probe
- TCP connectivity to the listener

> **Important:** Allow time for replication to fully settle before failback. Do not fail back immediately after the original failover without confirming data sync and service stability.

---

## Communication template
Use this one-liner during the incident bridge / stakeholder update:

> **Status:** NileRetail production failover in progress — primary region issue confirmed, West Europe promoted as active primary, validation checks running, next update in 15 minutes.

---

## Post-incident checklist
- Record exact failover timestamp
- Capture screenshots/logs for:
  - failover-group role change
  - Front Door health
  - app health probe
  - database connectivity validation
- Update incident timeline
- Open follow-up actions for:
  - root cause analysis
  - alert tuning
  - runbook improvements
