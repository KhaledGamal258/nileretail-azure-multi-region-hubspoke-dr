# NileRetail Group — Azure Multi‑Region Production + DR (Hub & Spoke over VPN S2S)

> **مشروع Portfolio** (شركة وهمية + بيانات مُنقّحة).  
> الهدف: تصميم منصة Azure **Multi‑Region** عالية الاعتمادية لتطبيق e‑commerce (موبايل/ويب) باستخدام **Hub & Spoke** و **Private Connectivity** و **DR**.

> **سياق التدريب:** المشروع ده اتصمم وانبنى مني خلال فترة عملي كـ **Cloud Engineer Intern في شركة GBG، مصر**.  
> GBG مش المالك بتاع المشروع ده — ده شغل Portfolio شخصي بتاعي، بيستخدم عميل وهمي، وما فيهوش أي معلومات سرية أو ملكية خاصة بـ GBG.

اقرأ النسخة الإنجليزية الأفضل للـ Hiring Managers: **README.md**  
الملف ده مجرد ملخص عربي سريع.

---

## اللي الريبو بيعرضه
- Azure Front Door Premium (WAF) + Private Origin
- North Europe (Primary) + West Europe (Secondary/DR)
- Hub في UK South
- VPN S2S (VNet‑to‑VNet) بدل Peering — تشفير IPSec/IKEv2، توجيه مركزي عبر الـ Hub، وجاهزية للاتصال بـ On-Premises مستقبلاً
- Private Endpoints + Private DNS Zones
- Azure SQL Auto‑Failover Group

---

## الدياجرامز
- HLD: `diagrams/HLD.png`
- LLD: `diagrams/LLD.png`

---

## الدوكيومنتيشن
ابدأ من `docs/` وبالذات:
- `docs/01-network-design.md`
- `docs/02-security.md`
- `docs/04-data-platform.md`
