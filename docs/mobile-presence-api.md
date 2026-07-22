# Awfar CC — Mobile Presence API

مواصفات تكامل تطبيق الموبايل (APK) مع تقارير السوبرفايزر.

| الحالة | `status` | السوبرفايزر |
|--------|----------|-------------|
| متاح | `online` | Online |
| خرج | `offline` | Offline (عند logout فقط) |
| في مكالمة | `incall` | In Call |
| عدم إزعاج | `dnd` | DND |

---

## إعدادات التطبيق (SIP Account)

| الحقل | مثال |
|-------|------|
| **Backend / Webphone API URL** | `https://phone-test.awfarcc.com/api-files` |
| **Registration Secret** | `AWF-SIP-REG-2026-X9K4M7` |
| **Extension** | Username / Extension (مثل `202`) |
| **SIP Server** | FreePBX (منفصل) |

> Base URL = `/api-files` وليس `/api`.

---

## Endpoints

```
{apiBaseUrl}/mobile_presence.php?action=register|status|logout
```

| Action | Method | Auth |
|--------|--------|------|
| `register` | POST | لا (secret في body) |
| `status` | POST | Bearer token |
| `logout` | POST | Bearer token |

---

## Register

```http
POST {apiBaseUrl}/mobile_presence.php?action=register
Content-Type: application/json

{
  "extension": "202",
  "registration_secret": "AWF-SIP-REG-2026-X9K4M7"
}
```

**Response 200:**

```json
{
  "success": true,
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "session_id": "...",
  "agent": { "id": 5, "extension": "202", "name": "Agent 202", "role": "agent" },
  "expires_at": "2026-07-20 15:30:00"
}
```

---

## Status (كل 5 ثوانٍ + فوراً عند تغيّر الحالة)

```http
POST {apiBaseUrl}/mobile_presence.php?action=status
Authorization: Bearer {token}

{
  "extension": "202",
  "status": "online"
}
```

**Statuses:** `online` | `dnd` | `incall` — لا ترسل `offline` أثناء عمل التطبيق.

---

## Logout

```http
POST {apiBaseUrl}/mobile_presence.php?action=logout
Authorization: Bearer {token}

{ "logout_type": "manual" }
```

---

## منطق التطبيق (مُنفَّذ)

```text
SIP Register OK → POST register → heartbeat كل 5s
مكالمة → incall (فوراً)
انتهاء مكالمة → online/dnd
DND → dnd
إغلاق/Logout → POST logout
401 → إعادة register
```

---

## cURL

```bash
curl -X POST "https://phone-test.awfarcc.com/api-files/mobile_presence.php?action=register" \
  -H "Content-Type: application/json" \
  -d '{"extension":"202","registration_secret":"AWF-SIP-REG-2026-X9K4M7"}'

curl -X POST "https://phone-test.awfarcc.com/api-files/mobile_presence.php?action=status" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TOKEN" \
  -d '{"extension":"202","status":"online"}'
```

**Reports:** https://phone-test.awfarcc.com/admin/reports
