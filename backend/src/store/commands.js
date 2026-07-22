/**
 * In-memory command queue for webphone → mobile softphone integration.
 * Replace with Redis/PostgreSQL in production.
 */

const { v4: uuid } = require('uuid');

/** @type {Map<string, object[]>} extension -> pending commands */
const pendingByExtension = new Map();

/** @type {Map<string, object>} commandId -> command record */
const allCommands = new Map();

function enqueueCommand({ targetExtension, action, number, dtmf, callId, clientRef, autoDial, source }) {
  const id = uuid();
  const cmd = {
    id,
    targetExtension: String(targetExtension),
    action,
    number: number ?? null,
    dtmf: dtmf ?? null,
    callId: callId ?? null,
    clientRef: clientRef ?? null,
    autoDial: autoDial !== false,
    source: source ?? 'web',
    status: 'pending',
    createdAt: new Date().toISOString(),
    deliveredAt: null,
    ackAt: null,
    ackStatus: null,
    ackError: null,
  };

  allCommands.set(id, cmd);
  const list = pendingByExtension.get(cmd.targetExtension) ?? [];
  list.push(cmd);
  pendingByExtension.set(cmd.targetExtension, list);
  return cmd;
}

function pullPending(extension, { limit = 10 } = {}) {
  const key = String(extension);
  const list = pendingByExtension.get(key) ?? [];
  if (list.length === 0) return [];

  const batch = list.splice(0, limit);
  pendingByExtension.set(key, list);

  const now = new Date().toISOString();
  for (const cmd of batch) {
    cmd.status = 'delivered';
    cmd.deliveredAt = now;
  }
  return batch;
}

function ackCommand(id, { status, error }) {
  const cmd = allCommands.get(id);
  if (!cmd) return null;
  cmd.status = status === 'executed' ? 'executed' : 'failed';
  cmd.ackAt = new Date().toISOString();
  cmd.ackStatus = status;
  cmd.ackError = error ?? null;
  return cmd;
}

function getCommand(id) {
  return allCommands.get(id) ?? null;
}

function listRecent({ limit = 50 } = {}) {
  return [...allCommands.values()]
    .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
    .slice(0, limit);
}

module.exports = {
  enqueueCommand,
  pullPending,
  ackCommand,
  getCommand,
  listRecent,
};
