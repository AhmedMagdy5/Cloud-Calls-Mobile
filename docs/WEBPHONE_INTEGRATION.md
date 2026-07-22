# Webphone Integration API

Bridge between **Awfar CallCenter web CRM / browser webphone** and the **Awfar CC mobile softphone**.

## Architecture

```
Web CRM / Webphone                Integration API              Mobile App
     │                                  │                           │
     │  POST /integration/webphone/send │                           │
     ├─────────────────────────────────►│  queue command            │
     │                                  │◄──────────────────────────┤
     │                                  │  GET /integration/commands│
     │                                  │  (poll every 5s)          │
     │                                  ├──────────────────────────►│
     │                                  │                           │ makeCall()
     │  GET /integration/commands/:id   │◄──────────────────────────┤
     │◄─────────────────────────────────┤  POST .../ack             │
```

Optional: send FCM push with `type: webphone_command` for instant delivery.

## Quick start

### 1. Run the API server

```bash
cd backend
cp .env.example .env
npm install
npm start
```

Server listens on `http://localhost:3001`.

### 2. Point the mobile app

Edit `lib/core/constants/app_config.dart`:

```dart
static const String apiBaseUrl = 'http://YOUR_PC_IP:3001/api';
```

- Android emulator → `http://10.0.2.2:3001/api`
- Physical device → `http://192.168.x.x:3001/api` (same Wi‑Fi as PC)

### 3. Login on mobile

Use backend login with demo credentials from `.env` (default `1001` / `1001`).

---

## Authentication

| Method | Header | Use case |
|--------|--------|----------|
| JWT | `Authorization: Bearer <token>` | Agent mobile app, logged-in web UI |
| API key | `X-API-Key: <INTEGRATION_API_KEY>` | CRM server → send commands without user session |

Get JWT:

```http
POST /api/auth/login
Content-Type: application/json

{
  "username": "1001",
  "password": "1001"
}
```

---

## Send command (web → mobile)

```http
POST /api/integration/webphone/send
Authorization: Bearer <token>
# OR
X-API-Key: awfar-webphone-key-change-me

Content-Type: application/json

{
  "targetExtension": "1001",
  "action": "dial",
  "number": "01234567890",
  "autoDial": true,
  "clientRef": "crm-lead-42"
}
```

**Response `202`:**

```json
{
  "commandId": "uuid",
  "status": "queued",
  "targetExtension": "1001",
  "action": "dial",
  "createdAt": "2026-06-23T12:00:00.000Z"
}
```

### Actions

| action | Required fields | Mobile behavior |
|--------|-----------------|-----------------|
| `dial` | `number` | Opens active call screen and places SIP call |
| `prefill` | `number` | Opens dialer with number filled (no auto-dial) |
| `hangup` | — | Ends current call |
| `hold` | — | SIP hold |
| `unhold` | — | SIP unhold |
| `park` | — | Local hold (multi-call) |
| `answer` | — | Answer ringing call |
| `dtmf` | `dtmf` | Send DTMF tone |

Set `"autoDial": false` on `dial` to only prefill the dialer.

---

## Check command status

```http
GET /api/integration/commands/{commandId}
X-API-Key: awfar-webphone-key-change-me
```

Returns `pending` → `delivered` → `executed` or `failed`.

---

## JavaScript example (web CRM click-to-dial)

```javascript
async function clickToDial(agentExtension, phoneNumber) {
  const res = await fetch('http://localhost:3001/api/integration/webphone/send', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-API-Key': 'awfar-webphone-key-change-me',
    },
    body: JSON.stringify({
      targetExtension: agentExtension,
      action: 'dial',
      number: phoneNumber,
      autoDial: true,
      clientRef: `lead-${Date.now()}`,
    }),
  });
  const data = await res.json();
  console.log('Command queued:', data.commandId);
  return data;
}
```

---

## FCM push (optional, instant)

When Firebase is configured, your backend can also push:

```json
{
  "type": "webphone_command",
  "action": "dial",
  "number": "01234567890",
  "autoDial": "true",
  "commandId": "optional-uuid"
}
```

---

## Production notes

- Replace in-memory queue (`backend/src/store/commands.js`) with Redis or PostgreSQL.
- Wire `/api/auth/login` to your real FreePBX / LDAP auth and return real SIP credentials.
- Use HTTPS and rotate `JWT_SECRET` + `INTEGRATION_API_KEY`.
- For browser SIP webphone (JsSIP / SIP.js), use the same `/api/auth/login` SIP block — no integration API needed for in-browser calls.
