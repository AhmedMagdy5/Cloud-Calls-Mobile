# Webphone Send API — Awfar CC Mobile

This document describes the **Send API** and related integration endpoints used to control the mobile softphone from a web CRM / webphone.

The mobile app reads the base URL from **SIP Account → Backend / Webphone API URL** (saved per device). Default paths below are appended to that base URL.

---

## Base URL

| Setting | Default path |
|--------|----------------|
| API base URL | `https://your-domain.com/api` *(configured in app)* |
| Send command | `/integration/webphone/send` |
| Pull commands | `/integration/commands` |
| Ack command | `/integration/commands/{commandId}/ack` |

**Headers (all requests from mobile):**

```http
Content-Type: application/json
Accept: application/json
Authorization: Bearer {access_token}   # after backend login
```

---

## 1. Send command (Web → Backend → Mobile)

Used by your **web CRM / webphone backend** to queue a remote action for an agent extension.

### Request

```http
POST {apiBaseUrl}/integration/webphone/send
```

### Body

```json
{
  "targetExtension": "200",
  "action": "dial",
  "number": "01012345678",
  "autoDial": true,
  "callId": "optional-call-id",
  "clientRef": "optional-client-reference"
}
```

### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `targetExtension` | string | **Yes** | Agent SIP extension / username to receive the command |
| `action` | string | **Yes** | Command name (see supported actions below) |
| `number` | string | For `dial`, `prefill` | Phone number to dial or prefill |
| `dtmf` | string | For `dtmf` | DTMF digits to send (e.g. `"1"`, `"*9"`) |
| `autoDial` | boolean | No | Default `true`. If `false` with `dial`, opens dialer without auto-calling |
| `callId` | string | No | Your server-side call reference |
| `clientRef` | string | No | CRM / ticket reference |

### Supported `action` values

| Action | Required fields | Mobile behavior |
|--------|-----------------|-----------------|
| `dial` | `number` | Opens call screen and places call (if `autoDial` is true) |
| `prefill` | `number` | Fills dialer only; user taps Call |
| `hangup` | — | Ends active call |
| `hold` | — | Puts call on hold |
| `unhold` | — | Resumes held call |
| `park` | — | Parks current call |
| `answer` | — | Answers ringing incoming call |
| `dtmf` | `dtmf` | Sends DTMF tone(s) on active call |

### Example — dial

```json
{
  "targetExtension": "200",
  "action": "dial",
  "number": "+201012345678",
  "autoDial": true,
  "clientRef": "ticket-8842"
}
```

### Example — hangup

```json
{
  "targetExtension": "200",
  "action": "hangup"
}
```

### Example — DTMF

```json
{
  "targetExtension": "200",
  "action": "dtmf",
  "dtmf": "1"
}
```

### Expected response (suggested)

Your backend should return the queued command so the mobile can poll or push it:

```json
{
  "id": "cmd_7f3a9b2c",
  "status": "queued",
  "targetExtension": "200",
  "action": "dial",
  "number": "+201012345678",
  "autoDial": true,
  "createdAt": "2026-07-19T11:30:00.000Z"
}
```

---

## 2. Pull commands (Mobile polling)

The app polls every **5 seconds** for pending commands for the logged-in agent.

### Request

```http
GET {apiBaseUrl}/integration/commands?limit=10
```

### Expected response

```json
{
  "items": [
    {
      "id": "cmd_7f3a9b2c",
      "action": "dial",
      "number": "01012345678",
      "autoDial": true,
      "dtmf": null
    }
  ]
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `items` | array | **Yes** | List of pending commands |
| `items[].id` | string | **Yes** | Unique command ID (used for ack) |
| `items[].action` | string | **Yes** | Same actions as Send API |
| `items[].number` | string | For dial/prefill | Phone number |
| `items[].dtmf` | string | For dtmf | DTMF digits |
| `items[].autoDial` | boolean | No | Default treated as `true` if omitted |

---

## 3. Ack command (Mobile → Backend)

After executing a polled command, the app confirms success or failure.

### Request

```http
POST {apiBaseUrl}/integration/commands/{commandId}/ack
```

### Body — success

```json
{
  "status": "executed"
}
```

### Body — failure

```json
{
  "status": "failed",
  "error": "Missing number"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `status` | string | **Yes** | `"executed"` or `"failed"` |
| `error` | string | No | Error message when `status` is `"failed"` |

> **Note:** Commands delivered via FCM push are **not** acked by the mobile app.

---

## 4. FCM push (optional — instant delivery)

For faster delivery, send a Firebase data message instead of (or in addition to) polling.

### FCM data payload

```json
{
  "type": "webphone_command",
  "commandId": "cmd_7f3a9b2c",
  "action": "dial",
  "number": "01012345678",
  "autoDial": "true"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | **Yes** | Must be `"webphone_command"` |
| `commandId` | string | No | Your command reference |
| `action` | string | **Yes** | Same actions as Send API |
| `number` | string | For dial/prefill | Phone number |
| `dtmf` | string | For dtmf | DTMF digits |
| `autoDial` | string | No | `"false"` to disable auto-dial; any other value = true |

---

## 5. Push device registration (Mobile → Backend)

After login, the app registers its FCM token:

```http
POST {apiBaseUrl}/push/register
```

```json
{
  "token": "fcm-device-token",
  "platform": "mobile"
}
```

---

## 6. Backend login (optional)

If agents use **backend login** (not direct SIP), the app expects:

```http
POST {apiBaseUrl}/auth/login
```

```json
{
  "username": "200",
  "password": "secret"
}
```

### Response

```json
{
  "token": "jwt-access-token",
  "refreshToken": "optional-refresh-token",
  "user": {
    "id": "200",
    "name": "Agent Name",
    "email": "agent@example.com",
    "extension": "200"
  },
  "sip": {
    "server": "pbx.example.com",
    "port": 5060,
    "transport": "wss",
    "username": "200",
    "password": "sip-secret",
    "path": "/ws",
    "displayName": "Agent Name"
  }
}
```

---

## Integration flow

```text
Web CRM / Webphone
        │
        ▼
POST /integration/webphone/send  ──►  Backend queues command for extension
        │
        ├─► FCM push (type: webphone_command)  ──►  Mobile executes immediately
        │
        └─► GET /integration/commands (poll 5s)  ──►  Mobile executes
                    │
                    ▼
        POST /integration/commands/{id}/ack
```

---

## cURL examples

### Send dial command

```bash
curl -X POST "https://crm.example.com/api/integration/webphone/send" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "targetExtension": "200",
    "action": "dial",
    "number": "01012345678",
    "autoDial": true
  }'
```

### Pull pending commands

```bash
curl "https://crm.example.com/api/integration/commands?limit=10" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Ack executed command

```bash
curl -X POST "https://crm.example.com/api/integration/commands/cmd_7f3a9b2c/ack" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"status":"executed"}'
```

---

## Mobile app configuration

Each client configures in the app (no rebuild required):

1. Open **Settings → SIP Account**
2. Set **Backend / Webphone API URL** (e.g. `https://crm.example.com/api`)
3. Set SIP credentials
4. Tap **Save & Apply**

Custom API paths are supported if your backend uses different routes (stored separately on device; defaults listed above).
