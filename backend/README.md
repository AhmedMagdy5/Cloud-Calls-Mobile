# Awfar CC Integration API

REST gateway for webphone → mobile softphone commands.

See [../docs/WEBPHONE_INTEGRATION.md](../docs/WEBPHONE_INTEGRATION.md) for full API documentation.

## Run locally

```bash
npm install
cp .env.example .env
npm start
```

Default: `http://localhost:3001`

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/auth/login` | Agent login + SIP creds |
| POST | `/api/integration/webphone/send` | Queue command for agent extension |
| GET | `/api/integration/commands` | Mobile polls pending commands |
| POST | `/api/integration/commands/:id/ack` | Mobile ack execution |
| GET | `/api/integration/commands/:id` | Command status lookup |
