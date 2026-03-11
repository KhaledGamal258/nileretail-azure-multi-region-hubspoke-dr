#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# NileRetail Group — DNS + Connectivity Validation
#
# Run this from a Linux VM inside the Hub or either Spoke VNet.
# Requirements:
#   - Azure CLI logged in (az login)
#   - dig OR nslookup installed (dnsutils/bind-utils)
#   - curl + nc (netcat)
#
# What this script checks:
#   1) Private DNS resolution for Azure SQL Failover Group listener (database.windows.net)
#   2) Private DNS resolution for App Service Private Endpoint (azurewebsites.net + scm)
#   3) Connectivity to Application Gateway health probe endpoint
# -----------------------------------------------------------------------------

# -------------------------------
# Project naming (override via env vars)
# -------------------------------
WORKLOAD="${WORKLOAD:-ecom}"
ENV="${ENV:-prd}"

# Resource groups (override if your RG naming differs)
RG_NEU="${RG_NEU:-rg-${WORKLOAD}-${ENV}-neu-spoke}"
RG_WEU="${RG_WEU:-rg-${WORKLOAD}-${ENV}-weu-spoke}"

# SQL logical servers (from naming convention)
SQL_PRIMARY_SERVER="${SQL_PRIMARY_SERVER:-sqlsrv-${WORKLOAD}-${ENV}-neu-01}"
SQL_SECONDARY_SERVER="${SQL_SECONDARY_SERVER:-sqlsrv-${WORKLOAD}-${ENV}-weu-01}"

# Failover group name (script auto-discovers if empty)
SQL_FOG_NAME="${SQL_FOG_NAME:-}"

# App Services (per region)
APP_NEU_NAME="${APP_NEU_NAME:-app-${WORKLOAD}-${ENV}-neu-01}"
APP_WEU_NAME="${APP_WEU_NAME:-app-${WORKLOAD}-${ENV}-weu-01}"

# Application Gateways (per region)
AGW_NEU_NAME="${AGW_NEU_NAME:-agw-${WORKLOAD}-${ENV}-neu-01}"
AGW_WEU_NAME="${AGW_WEU_NAME:-agw-${WORKLOAD}-${ENV}-weu-01}"

# Probe path used by App Gateway health probe
HEALTH_PATH="${HEALTH_PATH:-/health}"

# Prefer dig if available; otherwise fall back to nslookup
DNS_TOOL="dig"
if ! command -v dig >/dev/null 2>&1; then
  DNS_TOOL="nslookup"
fi

say() {
  echo
  echo "============================================================"
  echo "$1"
  echo "============================================================"
}

resolve_name() {
  local fqdn="$1"
  echo "[DNS] Resolving: ${fqdn}"
  if [[ "$DNS_TOOL" == "dig" ]]; then
    dig +short "$fqdn" | sed '/^$/d'
  else
    nslookup "$fqdn" | awk '/^Address: /{print $2}' | sed '1d' || true
  fi
}

require_az() {
  if ! command -v az >/dev/null 2>&1; then
    echo "ERROR: Azure CLI (az) is required." >&2
    exit 1
  fi
}

require_az

# -------------------------------
# 1) SQL Failover Group DNS
# -------------------------------
say "1) Azure SQL Failover Group — Private DNS resolution"

if [[ -z "$SQL_FOG_NAME" ]]; then
  echo "[INFO] Discovering failover group name from: $RG_NEU / $SQL_PRIMARY_SERVER"
  SQL_FOG_NAME=$(az sql failover-group list \
    --resource-group "$RG_NEU" \
    --server "$SQL_PRIMARY_SERVER" \
    --query '[0].name' -o tsv 2>/dev/null || true)
fi

if [[ -z "$SQL_FOG_NAME" ]]; then
  echo "ERROR: Could not discover failover group name. Set SQL_FOG_NAME env var and re-run." >&2
  exit 1
fi

SQL_FOG_FQDN="${SQL_FOG_NAME}.database.windows.net"
echo "[INFO] Using failover group listener: ${SQL_FOG_FQDN}"

SQL_IPS=$(resolve_name "$SQL_FOG_FQDN" || true)
if [[ -z "$SQL_IPS" ]]; then
  echo "ERROR: DNS did not return an IP for ${SQL_FOG_FQDN}." >&2
  exit 1
fi

echo "[OK] ${SQL_FOG_FQDN} resolves to:"
echo "$SQL_IPS" | sed 's/^/  - /'

echo "[NET] Checking TCP 1433 connectivity to listener (nc -vz)"
SQL_FIRST_IP=$(echo "$SQL_IPS" | head -n 1)
if command -v nc >/dev/null 2>&1; then
  nc -vz -w 3 "$SQL_FIRST_IP" 1433
  echo "[OK] TCP 1433 reachable on ${SQL_FIRST_IP}:1433"
else
  echo "[WARN] nc not installed; skipping TCP 1433 check. Install: sudo apt-get install -y netcat-openbsd"
fi

# -------------------------------
# 2) App Service Private Endpoint DNS
# -------------------------------
say "2) App Service — Private DNS resolution (azurewebsites.net + SCM)"

for app in "$APP_NEU_NAME" "$APP_WEU_NAME"; do
  APP_FQDN="${app}.azurewebsites.net"
  SCM_FQDN="${app}.scm.azurewebsites.net"

  echo
  echo "[INFO] App: ${app}"

  APP_IPS=$(resolve_name "$APP_FQDN" || true)
  if [[ -z "$APP_IPS" ]]; then
    echo "ERROR: DNS did not return an IP for ${APP_FQDN}" >&2
    exit 1
  fi
  echo "[OK] ${APP_FQDN} resolves to:"
  echo "$APP_IPS" | sed 's/^/  - /'

  SCM_IPS=$(resolve_name "$SCM_FQDN" || true)
  if [[ -z "$SCM_IPS" ]]; then
    echo "ERROR: DNS did not return an IP for ${SCM_FQDN}" >&2
    exit 1
  fi
  echo "[OK] ${SCM_FQDN} resolves to:"
  echo "$SCM_IPS" | sed 's/^/  - /'

done

# -------------------------------
# 3) Application Gateway health probe connectivity
# -------------------------------
say "3) Application Gateway — Health probe connectivity"

get_agw_ip() {
  local rg="$1"
  local agw="$2"

  # Prefer private frontend IP if the gateway is internal
  local privateIp
  privateIp=$(az network application-gateway show -g "$rg" -n "$agw" \
    --query 'frontendIPConfigurations[0].privateIPAddress' -o tsv 2>/dev/null || true)

  if [[ -n "$privateIp" && "$privateIp" != "null" ]]; then
    echo "$privateIp"
    return 0
  fi

  # Otherwise try public frontend IP
  local pipId
  pipId=$(az network application-gateway show -g "$rg" -n "$agw" \
    --query 'frontendIPConfigurations[0].publicIPAddress.id' -o tsv 2>/dev/null || true)
  if [[ -z "$pipId" || "$pipId" == "null" ]]; then
    echo ""
    return 0
  fi

  az network public-ip show --ids "$pipId" --query 'ipAddress' -o tsv 2>/dev/null || true
}

AGW_IP=""
AGW_IP=$(get_agw_ip "$RG_NEU" "$AGW_NEU_NAME" || true)
AGW_RG_USED="$RG_NEU"
AGW_NAME_USED="$AGW_NEU_NAME"

if [[ -z "$AGW_IP" ]]; then
  AGW_IP=$(get_agw_ip "$RG_WEU" "$AGW_WEU_NAME" || true)
  AGW_RG_USED="$RG_WEU"
  AGW_NAME_USED="$AGW_WEU_NAME"
fi

if [[ -z "$AGW_IP" ]]; then
  echo "ERROR: Could not discover Application Gateway IP from either region." >&2
  echo "       Set AGW_NEU_NAME/AGW_WEU_NAME + RG_NEU/RG_WEU correctly and retry." >&2
  exit 1
fi

echo "[INFO] Using App Gateway: ${AGW_NAME_USED} (RG: ${AGW_RG_USED})"
echo "[INFO] Probing: https://${AGW_IP}${HEALTH_PATH}"

if command -v curl >/dev/null 2>&1; then
  curl -k -s -o /dev/null -w "[HTTP] Status: %{http_code}\n" "https://${AGW_IP}${HEALTH_PATH}"
  echo "[OK] Probe completed (check status code above)."
else
  echo "[WARN] curl not installed; skipping HTTP probe." >&2
fi

say "All checks finished ✅"
