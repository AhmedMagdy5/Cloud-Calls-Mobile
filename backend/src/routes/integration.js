const express = require('express');
const {
  enqueueCommand,
  pullPending,
  ackCommand,
  getCommand,
  listRecent,
} = require('../store/commands');
const { integrationAuth, authMiddleware } = require('../middleware/auth');

const router = express.Router();

const ALLOWED_ACTIONS = new Set([
  'dial',
  'hangup',
  'hold',
  'unhold',
  'park',
  'answer',
  'dtmf',
  'prefill',
]);

function validateSendBody(body) {
  const targetExtension = body?.targetExtension?.toString()?.trim();
  const action = body?.action?.toString()?.trim()?.toLowerCase();
  if (!targetExtension) return 'targetExtension is required';
  if (!action || !ALLOWED_ACTIONS.has(action)) {
    return `action must be one of: ${[...ALLOWED_ACTIONS].join(', ')}`;
  }
  if (action === 'dial' && !body?.number?.toString()?.trim()) {
    return 'number is required for dial action';
  }
  if (action === 'dtmf' && !body?.dtmf?.toString()?.trim()) {
    return 'dtmf is required for dtmf action';
  }
  return null;
}

/**
 * POST /integration/webphone/send
 * Web CRM / browser webphone sends a command to an agent's mobile softphone.
 */
router.post('/webphone/send', integrationAuth, (req, res) => {
  const err = validateSendBody(req.body);
  if (err) return res.status(400).json({ error: err });

  const {
    targetExtension,
    action,
    number,
    dtmf,
    callId,
    clientRef,
    autoDial,
  } = req.body;

  const cmd = enqueueCommand({
    targetExtension,
    action,
    number: number?.toString()?.trim(),
    dtmf: dtmf?.toString()?.trim(),
    callId: callId?.toString(),
    clientRef: clientRef?.toString(),
    autoDial: autoDial !== false,
    source: req.integrationSource === 'api_key' ? 'crm' : 'web',
  });

  res.status(202).json({
    commandId: cmd.id,
    status: 'queued',
    targetExtension: cmd.targetExtension,
    action: cmd.action,
    createdAt: cmd.createdAt,
  });
});

/**
 * GET /integration/commands
 * Mobile app polls pending commands for the logged-in agent extension.
 */
router.get('/commands', authMiddleware, (req, res) => {
  const extension = req.user.extension?.toString();
  if (!extension) {
    return res.status(400).json({ error: 'Token missing extension claim' });
  }
  const limit = Math.min(Number(req.query.limit) || 10, 50);
  const items = pullPending(extension, { limit });
  res.json({ items });
});

/**
 * POST /integration/commands/:id/ack
 * Mobile confirms command execution.
 */
router.post('/commands/:id/ack', authMiddleware, (req, res) => {
  const { status, error } = req.body ?? {};
  if (!['executed', 'failed'].includes(status)) {
    return res.status(400).json({ error: 'status must be executed or failed' });
  }
  const cmd = ackCommand(req.params.id, { status, error });
  if (!cmd) return res.status(404).json({ error: 'Command not found' });
  res.json({ ok: true, command: cmd });
});

/** GET /integration/commands/:id — status lookup for web CRM */
router.get('/commands/:id', integrationAuth, (req, res) => {
  const cmd = getCommand(req.params.id);
  if (!cmd) return res.status(404).json({ error: 'Command not found' });
  res.json(cmd);
});

/** GET /integration/commands/recent — debug / supervisor */
router.get('/commands-recent', integrationAuth, (req, res) => {
  const limit = Math.min(Number(req.query.limit) || 50, 200);
  res.json({ items: listRecent({ limit }) });
});

module.exports = router;
