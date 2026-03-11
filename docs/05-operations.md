# Operations & observability

---

## Overview
This project uses a **centralized operations model**:
- One **Log Analytics Workspace** in the **Hub** resource group: `log-ecom-prd-uks-01`
- Diagnostic settings enabled across edge, ingress, app, data, and network resources
- Azure Monitor alerting for availability, security, failover events, and VPN health
- Two dashboard views:
  - **Executive view** for service health and business continuity
  - **Operations view** for troubleshooting and day-to-day incident response

---

## Logging setup

### Central workspace
| Item | Value |
|---|---|
| Log Analytics Workspace | `log-ecom-prd-uks-01` |
| Resource Group | `rg-ecom-prd-uks-hub` |
| Region | `UK South` |
| Interactive retention | **30 days** |
| Archive retention | **90 days** |

### Diagnostic settings scope
Enable diagnostic settings on the following resources and send logs/metrics to `log-ecom-prd-uks-01`:

| Resource | Example name |
|---|---|
| Azure Front Door Premium | `afd-ecom-prd-01` |
| Application Gateway (North Europe) | `agw-ecom-prd-neu-01` |
| Application Gateway (West Europe) | `agw-ecom-prd-weu-01` |
| App Service (North Europe) | `app-ecom-prd-neu-01` |
| App Service (West Europe) | `app-ecom-prd-weu-01` |
| Azure SQL (North Europe) | `sqlsrv-ecom-prd-neu-01` |
| Azure SQL (West Europe) | `sqlsrv-ecom-prd-weu-01` |
| VPN Gateway (Hub) | `vpngw-ecom-prd-uks-01` |
| VPN Gateway (North Europe) | `vpngw-ecom-prd-neu-01` |
| VPN Gateway (West Europe) | `vpngw-ecom-prd-weu-01` |
| Azure Firewall Premium | `azfw-ecom-prd-uks-01` |

---

## Core KQL queries

### 1) WAF blocks in the last 24 hours
```kusto
AzureDiagnostics
| where TimeGenerated > ago(24h)
| where action_s == "Block"
| summarize BlockCount = count() by clientIP_s, ruleName_s
| order by BlockCount desc
```

### 2) Application Gateway 5xx errors
```kusto
AzureDiagnostics
| where TimeGenerated > ago(24h)
| where httpStatus_d >= 500
| summarize ErrorCount = count() by requestUri_s
| order by ErrorCount desc
```

### 3) SQL connection failures
```kusto
AzureDiagnostics
| where TimeGenerated > ago(24h)
| where Category == "SQLSecurityAuditEvents"
| where action_name_s == "CONNECTION_FAILED"
| summarize FailureCount = count() by logical_server_name_s, database_name_s, client_ip_s
| order by FailureCount desc
```

### 4) VPN tunnel disconnects
```kusto
AzureDiagnostics
| where TimeGenerated > ago(24h)
| where Category == "TunnelDiagnosticLog"
| where message_s contains "Disconnected"
| summarize DisconnectCount = count() by Resource, message_s
| order by DisconnectCount desc
```

### 5) Front Door unhealthy origin probes
```kusto
AzureDiagnostics
| where TimeGenerated > ago(24h)
| where Category == "FrontDoorHealthProbeLog"
| where httpStatusCode_d != 200
| summarize ProbeFailures = count() by originName_s, httpStatusCode_d
| order by ProbeFailures desc
```

---

## Alert rules

> Notes:
> - Metrics alerts use `az monitor metrics alert create`.
> - Log-query alerts use `az monitor scheduled-query create`.
> - Replace action group IDs if you use email, Teams, webhook, or ITSM integrations.

Set these helpers once:
```bash
SUB_ID=$(az account show --query id -o tsv)

RG_HUB="rg-ecom-prd-uks-hub"
RG_NEU="rg-ecom-prd-neu-spoke"
RG_WEU="rg-ecom-prd-weu-spoke"

VPN_HUB_ID="/subscriptions/${SUB_ID}/resourceGroups/${RG_HUB}/providers/Microsoft.Network/virtualNetworkGateways/vpngw-ecom-prd-uks-01"
AGW_NEU_ID="/subscriptions/${SUB_ID}/resourceGroups/${RG_NEU}/providers/Microsoft.Network/applicationGateways/agw-ecom-prd-neu-01"
LAW_ID="/subscriptions/${SUB_ID}/resourceGroups/${RG_HUB}/providers/Microsoft.OperationalInsights/workspaces/log-ecom-prd-uks-01"
```

### 1) VPN tunnel down
**Severity:** 1  
**Logic:** Tunnel bytes drop to 0 over a 5-minute window

```bash
az monitor metrics alert create \
  -g "${RG_HUB}" \
  -n "alert-ecom-prd-vpn-tunnel-down-01" \
  --scopes "${VPN_HUB_ID}" \
  --severity 1 \
  --window-size 5m \
  --evaluation-frequency 5m \
  --condition "total TunnelIngressBytes < 1"
```

### 2) Application Gateway unhealthy backend
**Severity:** 2  
**Logic:** `UnhealthyHostCount > 0` over 5 minutes

```bash
az monitor metrics alert create \
  -g "${RG_NEU}" \
  -n "alert-ecom-prd-neu-agw-unhealthy-backend-01" \
  --scopes "${AGW_NEU_ID}" \
  --severity 2 \
  --window-size 5m \
  --evaluation-frequency 5m \
  --condition "max UnhealthyHostCount > 0"
```

> Repeat the same rule in West Europe with `agw-ecom-prd-weu-01`.

### 3) SQL failover role change
**Severity:** 1  
**Logic:** Alert when Azure Activity records a failover-group primary role change

```bash
az monitor scheduled-query create \
  -g "${RG_HUB}" \
  -n "alert-ecom-prd-sql-failover-role-change-01" \
  --scopes "/subscriptions/${SUB_ID}" \
  --severity 1 \
  --window-size 5m \
  --evaluation-frequency 5m \
  --condition "count 'FailoverRoleChange' > 0" \
  --condition-query "FailoverRoleChange=AzureActivity | where TimeGenerated > ago(5m) | where OperationNameValue has 'Microsoft.Sql/servers/failoverGroups/setPrimary/action' or OperationNameValue has 'Microsoft.Sql/servers/failoverGroups/write' | where ActivityStatusValue =~ 'Succeeded'" \
  --description "Detect failover-group role change for NileRetail production SQL"
```

### 4) WAF spike
**Severity:** 2  
**Logic:** More than 100 WAF blocks in 5 minutes

```bash
az monitor scheduled-query create \
  -g "${RG_HUB}" \
  -n "alert-ecom-prd-waf-block-spike-01" \
  --scopes "${LAW_ID}" \
  --severity 2 \
  --window-size 5m \
  --evaluation-frequency 5m \
  --condition "count 'WafBlocks' > 100" \
  --condition-query "WafBlocks=AzureDiagnostics | where TimeGenerated > ago(5m) | where action_s == 'Block'" \
  --description "Detect anomalous Front Door WAF block spike"
```

---

## Dashboards

### Executive view
Audience: management, service owners, incident bridge stakeholders

Widgets:
- **AFD availability %**
- **App Gateway request rate**
- **SQL DTU/vCore %**
- **Active VPN tunnels**

Purpose:
- Quick "is the platform healthy?" snapshot
- DR readiness and regional posture at a glance
- Useful during steering updates and go-live reviews

### Operations view
Audience: on-call engineers, platform team, escalation bridge

Widgets:
- **WAF block rate**
- **App Service response times**
- **SQL connection pool saturation**
- **5xx rate per region**

Purpose:
- Triage failed requests quickly
- Spot unhealthy backends, app slowdowns, SQL pressure, and regional asymmetry
- Support real-time incident response and after-action reviews

---

## Operational notes
- Keep **30 days interactive retention** for active investigations.
- Archive to **90 days** for post-incident lookback and monthly reporting.
- During DR drills, capture:
  - alert firing timestamps
  - SQL failover timestamps
  - Front Door origin health changes
  - screenshots of dashboards before/after failover
