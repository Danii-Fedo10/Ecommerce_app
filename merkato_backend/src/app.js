import http from 'node:http';
import { openDb } from './db.js';
import { loadConfig } from './config.js';
import { createChapa } from './chapa.js';
import { createServices } from './services.js';
import { buildRoutes } from './routes.js';
import { HttpError, verifyJwt } from './lib.js';

const MAX_BODY = 1_000_000;

/** Wire everything together. Pass overrides for tests. */
export function createApp(overrides = {}) {
  const config = loadConfig(overrides.config);
  const db = overrides.db || openDb(config.dbFile);
  const chapa = overrides.chapa || createChapa(config);
  const svc = createServices({ db, config, chapa });
  // TODO(production): plug a real SMS gateway here (e.g. Ethio Telecom / an aggregator). Never log OTPs in production.
  const sendSms = overrides.sendSms || (async (phone, text) => { if (!config.production) console.log(`[sms:${phone}] ${text}`); });
  const router = buildRoutes({ db, config, svc, chapa, sendSms });

  const server = http.createServer(async (req, res) => {
    const send = (status, data) => {
      res.writeHead(status, { 'Content-Type': 'application/json', 'X-Content-Type-Options': 'nosniff' });
      res.end(JSON.stringify(data));
    };
    try {
      const url = new URL(req.url, 'http://x');
      const m = router.match(req.method, url.pathname);
      if (!m) throw new HttpError(404, 'Not found');
      const { route, params } = m;

      const chunks = []; let size = 0;
      for await (const c of req) { size += c.length; if (size > MAX_BODY) throw new HttpError(413, 'Body too large'); chunks.push(c); }
      const raw = Buffer.concat(chunks).toString('utf8');
      let body = {};
      if (raw) { try { body = JSON.parse(raw); } catch { throw new HttpError(400, 'Invalid JSON'); } }

      let user = null;
      if (!route.opts?.public) {
        const h = req.headers.authorization || '';
        if (!h.startsWith('Bearer ')) throw new HttpError(401, 'Authentication required');
        const claims = verifyJwt(h.slice(7), config.jwtSecret);
        user = db.prepare('SELECT * FROM users WHERE id=?').get(claims.sub); // role always read fresh from DB
        if (!user) throw new HttpError(401, 'Unknown user');
        if (route.opts?.roles && !route.opts.roles.includes(user.role)) throw new HttpError(403, 'Forbidden for your role');
      }
      const ip = req.socket.remoteAddress || 'unknown';
      const out = await route.handler({ req, params, query: Object.fromEntries(url.searchParams), body, raw, headers: req.headers, user, ip });
      send(200, out);
    } catch (e) {
      if (e instanceof HttpError) return send(e.status, { error: e.message });
      console.error(e);
      send(500, { error: 'Internal server error' });
    }
  });

  return { server, db, svc, chapa, config };
}
