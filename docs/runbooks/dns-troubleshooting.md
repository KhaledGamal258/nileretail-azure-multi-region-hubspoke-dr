# Runbook — DNS troubleshooting

---

## Symptom
The application cannot reach **Azure SQL** or **App Service** via **Private Endpoint**.  
Typical symptoms:
- connection timeout
- name resolution failure
- intermittent 503 / backend unavailable

---

## Step 1 — Verify the Private DNS zones exist and are linked
```bash
az network private-dns zone list \
  -g rg-ecom-prd-uks-hub \
  --query "[].name" -o tsv

az network private-dns link vnet list \
  -g rg-ecom-prd-uks-hub \
  -z privatelink.database.windows.net \
  --query "[].{name:name,vnet:virtualNetwork.id,state:registrationEnabled}" -o table
```

Check for:
- `privatelink.database.windows.net`
- `privatelink.azurewebsites.net`
- VNet links for **Hub**, **North Europe spoke**, and **West Europe spoke**

---

## Step 2 — Verify the Private Endpoint exists and is approved
```bash
az network private-endpoint list -g rg-ecom-prd-neu-spoke -o table

az network private-endpoint show \
  -g rg-ecom-prd-neu-spoke \
  -n pep-sql-ecom-prd-neu-01 \
  --query "privateLinkServiceConnections[0].privateLinkServiceConnectionState" -o json
```

Expected:
```json
{
  "status": "Approved"
}
```

If the status is `Pending`, the connection must be approved on the target service.

---

## Step 3 — Verify the DNS Zone Group is attached
Do **not** rely on manual A records for Private Endpoint DNS.

```bash
az network private-endpoint dns-zone-group list \
  -g rg-ecom-prd-neu-spoke \
  --endpoint-name pep-sql-ecom-prd-neu-01 -o table
```

Expected:
- A zone group exists
- It references the correct Private DNS zone

---

## Step 4 — Test resolution from inside the VNet
Run from:
- **App Service Kudu console**
- or a **test VM** inside the spoke VNet

```bash
# Should resolve to a 10.x.x.x private IP, NOT a public Azure IP
nslookup sqlsrv-ecom-prd-neu-01.database.windows.net
nslookup fog-ecom-prd-01.database.windows.net
```

> If it resolves to a **public IP** (for example `13.x.x.x` or `52.x.x.x`), the Private DNS zone is **not linked** to this VNet or the Zone Group is missing.

---

## Step 5 — Test TCP connectivity
From App Service Kudu console:

```bash
# From App Service Kudu console (Tools → Debug console)
tcpping sqlsrv-ecom-prd-neu-01.database.windows.net:1433
```

Expected:
- TCP check succeeds

If DNS resolves correctly but TCP fails, the issue is usually network policy / NSG / routing.

---

## Common failure modes

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| Resolves to public IP | DNS zone not linked to spoke VNet | Add VNet link via `private-dns.bicep` |
| NXDOMAIN | DNS Zone Group not attached to PE | Add zone group to the PE |
| Resolves correctly but TCP times out | NSG blocking port | Check `snet-pe` NSG — allow inbound 1433 from `snet-appsvc-int` |
| Resolves correctly but 503 | App Service PE not approved | Approve pending PE connection on App Service |

---

## Escalation notes
If all checks pass but the app still fails:
1. Compare working region vs failing region
2. Review `docs/checklists/nsg-rules.md`
3. Validate App Service VNet integration settings
4. Review Front Door / App Gateway backend health
