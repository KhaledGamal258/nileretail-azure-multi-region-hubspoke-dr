# ADR 0002 — VPN S2S (VNet-to-VNet) instead of VNet peering

---

## Status
Accepted

---

## Context
NileRetail Group requires Hub ↔ Spoke connectivity across three Azure regions (UK South hub, North Europe spoke, West Europe spoke). Two options were evaluated: VNet Peering and VNet-to-VNet VPN.

---

## Decision
Use **VNet-to-VNet VPN gateways** between the hub and each spoke.

This was a hard requirement in the project scenario. However, it is also architecturally justifiable for an e-commerce workload with these security requirements.

---

## Rationale

### Security and encryption
VNet Peering transports traffic over the Microsoft backbone but the traffic is **not IPSec-encrypted** at the packet level — it relies on Microsoft's infrastructure isolation. VNet-to-VNet VPN uses **IKEv2 with AES-256-GCM encryption** end-to-end through the tunnel. For an e-commerce company handling customer payment data and personal information (GDPR scope), IPSec encryption provides a stronger and more auditable security guarantee.

### Isolation boundary
Each VNet-to-VNet VPN tunnel creates a logical isolation boundary with explicit Connection resources on both sides. This makes the connectivity intentional and observable — you can audit, revoke, or re-key any tunnel independently. VNet Peering, once established, is always-on and bidirectional by default.

### Routing control
VPN tunnels are routed through the hub VPN Gateway, which means all cross-spoke traffic flows through the hub where centralized inspection (Azure Firewall) can be applied. VNet Peering without an NVA in the hub does not support transitive routing — spoke-to-spoke traffic would not traverse the hub firewall automatically.

### Future on-premises connectivity
A hub with a VPN Gateway is ready for S2S VPN connections to on-premises networks (NileRetail's Egypt datacentre) without redesign. A peering-only hub would require adding a gateway later.

---

## Trade-offs accepted

| Factor | VNet Peering | VPN S2S |
|--------|-------------|---------|
| Throughput | Up to 10 Gbps+ | 650 Mbps–10 Gbps (SKU-dependent) |
| Latency | Lower (no gateway hop) | Slightly higher (gateway processing) |
| Cost | Per-GB transfer only | Gateway SKU hourly + per-GB transfer |
| Encryption | Infrastructure-level | IPSec AES-256-GCM |
| Transitive routing | Requires NVA | Native via hub gateway |

For this workload (e-commerce API, not high-throughput data pipeline), the throughput trade-off is acceptable. The security and routing benefits justify the additional cost.
