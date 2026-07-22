const jwt = require('jsonwebtoken');

function signToken(payload) {
  return jwt.sign(payload, process.env.JWT_SECRET || 'dev-secret', { expiresIn: '12h' });
}

function verifyToken(token) {
  return jwt.verify(token, process.env.JWT_SECRET || 'dev-secret');
}

function authMiddleware(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) {
    return res.status(401).json({ error: 'Missing Bearer token' });
  }
  try {
    req.user = verifyToken(token);
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

/** Server-to-server key for CRM / webphone backends */
function apiKeyMiddleware(req, res, next) {
  const expected = process.env.INTEGRATION_API_KEY;
  if (!expected) {
    return res.status(503).json({ error: 'INTEGRATION_API_KEY not configured' });
  }
  const key = req.headers['x-api-key'];
  if (key !== expected) {
    return res.status(401).json({ error: 'Invalid X-API-Key' });
  }
  next();
}

/** JWT (agent) OR X-API-Key (CRM server) */
function integrationAuth(req, res, next) {
  const apiKey = req.headers['x-api-key'];
  if (apiKey && apiKey === process.env.INTEGRATION_API_KEY) {
    req.integrationSource = 'api_key';
    return next();
  }
  return authMiddleware(req, res, next);
}

module.exports = {
  signToken,
  verifyToken,
  authMiddleware,
  apiKeyMiddleware,
  integrationAuth,
};
