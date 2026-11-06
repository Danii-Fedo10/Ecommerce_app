import crypto from 'node:crypto';

export class HttpError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}

export const uid = (prefix) => `${prefix}_${crypto.randomBytes(6).toString('hex')}`;
export const sha256 = (s) => crypto.createHash('sha256').update(s).digest('hex');

function safeEqual(a, b) {
  const x = Buffer.from(a), y = Buffer.from(b);
  return x.length === y.length && crypto.timingSafeEqual(x, y);
}

// --- Minimal HS256 JWT -------------------------------------------------------
export function signJwt(payload, secret, ttlSec = 7 * 86400) {
  const enc = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
  const head = enc({ alg: 'HS256', typ: 'JWT' });
  const body = enc({ ...payload, exp: Math.floor(Date.now() / 1000) + ttlSec });
  const sig = crypto.createHmac('sha256', secret).update(`${head}.${body}`).digest('base64url');
  return `${head}.${body}.${sig}`;
}

export function verifyJwt(token, secret) {
  const parts = String(token).split('.');
  if (parts.length !== 3) throw new HttpError(401, 'Invalid token');
  const expected = crypto.createHmac('sha256', secret).update(`${parts[0]}.${parts[1]}`).digest('base64url');
  if (!safeEqual(parts[2], expected)) throw new HttpError(401, 'Invalid token');
  const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString());
  if (!payload.exp || payload.exp < Math.floor(Date.now() / 1000)) throw new HttpError(401, 'Token expired');
  return payload;
}

export function hmacHex(secret, data) {
  return crypto.createHmac('sha256', secret).update(data).digest('hex');
}
export { safeEqual };

// --- Validation helpers ------------------------------------------------------
export function normalizePhone(p) {
  const m = String(p || '').replace(/[\s-]/g, '').match(/^(?:\+251|251|0)?([79]\d{8})$/);
  if (!m) throw new HttpError(400, 'Invalid Ethiopian mobile number');
  return `+251${m[1]}`;
}

export function int(v, name, { min = 0, max = 1e9 } = {}) {
  const n = Number(v);
  if (!Number.isInteger(n) || n < min || n > max) throw new HttpError(400, `${name} must be an integer between ${min} and ${max}`);
  return n;
}

export function str(v, name, { min = 1, max = 500 } = {}) {
  const s = typeof v === 'string' ? v.trim() : '';
  if (s.length < min || s.length > max) throw new HttpError(400, `${name} must be ${min}-${max} characters`);
  return s;
}

// --- Tiny in-memory rate limiter (use Redis when running more than one instance) ----
export function rateLimiter(max, windowMs) {
  const hits = new Map();
  return (key) => {
    const now = Date.now();
    const arr = (hits.get(key) || []).filter((t) => now - t < windowMs);
    if (arr.length >= max) throw new HttpError(429, 'Too many requests, try again later');
    arr.push(now);
    hits.set(key, arr);
  };
}

// --- Router ------------------------------------------------------------------
export class Router {
  routes = [];
  add(method, path, opts, handler) {
    const keys = [];
    const re = new RegExp('^' + path.replace(/:(\w+)/g, (_, k) => { keys.push(k); return '([^/]+)'; }) + '$');
    this.routes.push({ method, re, keys, opts, handler });
  }
  match(method, path) {
    for (const r of this.routes) {
      if (r.method !== method) continue;
      const m = r.re.exec(path);
      if (m) {
        const params = {};
        r.keys.forEach((k, i) => (params[k] = decodeURIComponent(m[i + 1])));
        return { route: r, params };
      }
    }
    return null;
  }
}
