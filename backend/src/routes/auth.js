const express = require('express');
const { signToken, authMiddleware } = require('../middleware/auth');

const router = express.Router();

router.post('/login', (req, res) => {
  const { username, password } = req.body ?? {};
  const demoUser = process.env.DEMO_USER || '1001';
  const demoPass = process.env.DEMO_PASS || '1001';

  if (username !== demoUser || password !== demoPass) {
    return res.status(401).json({ error: 'Invalid credentials' });
  }

  const extension = process.env.DEMO_EXTENSION || username;
  const token = signToken({ sub: username, extension, role: 'agent' });

  res.json({
    token,
    refreshToken: token,
    user: {
      id: username,
      name: process.env.DEMO_NAME || `Agent ${extension}`,
      email: `${username}@local`,
      extension,
      role: 'agent',
    },
    sip: {
      server: process.env.SIP_SERVER || 'sip.your-freepbx-domain.com',
      port: Number(process.env.SIP_PORT || 5060),
      transport: process.env.SIP_TRANSPORT || 'udp',
      username: extension,
      password: demoPass,
      displayName: process.env.DEMO_NAME || `Agent ${extension}`,
      path: '/ws',
    },
  });
});

router.post('/refresh', authMiddleware, (req, res) => {
  const token = signToken({
    sub: req.user.sub,
    extension: req.user.extension,
    role: req.user.role,
  });
  res.json({ token });
});

router.post('/logout', authMiddleware, (_req, res) => {
  res.json({ ok: true });
});

module.exports = router;
