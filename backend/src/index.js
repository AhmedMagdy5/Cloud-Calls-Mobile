require('dotenv').config();

const express = require('express');
const cors = require('cors');

const authRoutes = require('./routes/auth');
const integrationRoutes = require('./routes/integration');

const app = express();
const port = Number(process.env.PORT || 3001);

app.use(cors());
app.use(express.json());

app.get('/health', (_req, res) => {
  res.json({ ok: true, service: 'awfar-cc-integration-api' });
});

app.use('/api/auth', authRoutes);
app.use('/api/integration', integrationRoutes);

// Stubs so mobile app doesn't 404 on optional endpoints
app.post('/api/push/register', (_req, res) => res.json({ ok: true }));
app.post('/api/agents/status', (_req, res) => res.json({ ok: true }));
app.get('/api/voice/calls', (_req, res) => res.json({ items: [] }));

app.use((_req, res) => {
  res.status(404).json({ error: 'Not found' });
});

app.listen(port, () => {
  console.log(`Awfar CC Integration API listening on http://0.0.0.0:${port}`);
  console.log(`  POST /api/integration/webphone/send  — web → mobile command`);
  console.log(`  GET  /api/integration/commands       — mobile poll`);
  console.log(`  POST /api/auth/login                 — demo agent login`);
});
