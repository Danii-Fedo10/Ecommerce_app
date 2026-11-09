import crypto from 'node:crypto';
import { Router, HttpError, uid, sha256, signJwt, normalizePhone, int, str, rateLimiter } from './lib.js';

export function buildRoutes({ db, config, svc, chapa, sendSms }) {
  const r = new Router();
  const q = (sql) => db.prepare(sql);
  const otpLimit = rateLimiter(5, 10 * 60_000);
  const verifyLimit = rateLimiter(10, 10 * 60_000);
  const PUB = { public: true };
  const ROLE = (...roles) => ({ roles });
  const page = (query) => ({ limit: Math.min(Number(query.limit) || 20, 50), offset: Math.max(Number(query.page || 1) - 1, 0) * (Math.min(Number(query.limit) || 20, 50)) });

  r.add('GET', '/health', PUB, () => ({ ok: true }));

  // ---------- Auth: phone OTP ----------
  r.add('POST', '/api/auth/otp', PUB, async ({ body, ip }) => {
    const phone = normalizePhone(body.phone);
    otpLimit(phone); otpLimit(ip);
    const code = String(crypto.randomInt(100000, 1000000));
    q('INSERT OR REPLACE INTO otps(phone,code_hash,expires_at,attempts) VALUES (?,?,?,0)').run(phone, sha256(code + phone + config.jwtSecret), Date.now() + 5 * 60_000);
    await sendSms(phone, `Your Merkato Market code is ${code}. It expires in 5 minutes.`);
    return { sent: true, ...(config.exposeOtp ? { devCode: code } : {}) };
  });

  r.add('POST', '/api/auth/verify', PUB, ({ body, ip }) => {
    const phone = normalizePhone(body.phone);
    verifyLimit(ip);
    const row = q('SELECT * FROM otps WHERE phone=?').get(phone);
    if (!row || row.expires_at < Date.now() || row.attempts >= 5) throw new HttpError(401, 'Code expired or too many attempts');
    q('UPDATE otps SET attempts=attempts+1 WHERE phone=?').run(phone);
    if (sha256(String(body.code) + phone + config.jwtSecret) !== row.code_hash) throw new HttpError(401, 'Wrong code');
    q('DELETE FROM otps WHERE phone=?').run(phone);
    let user = q('SELECT * FROM users WHERE phone=?').get(phone);
    if (!user) {
      const role = config.adminPhones.includes(phone) ? 'admin' : 'buyer';
      const id = uid('u');
      q('INSERT INTO users(id,phone,name,role,created_at) VALUES (?,?,?,?,?)').run(id, phone, body.name ? str(body.name, 'name', { max: 80 }) : null, role, Date.now());
      user = q('SELECT * FROM users WHERE id=?').get(id);
    }
    return { token: signJwt({ sub: user.id, role: user.role }, config.jwtSecret), user: { id: user.id, phone: user.phone, name: user.name, role: user.role } };
  });

  r.add('GET', '/api/me', null, ({ user }) => {
    const s = q('SELECT status, shop_name AS shopName, tera FROM sellers WHERE user_id=?').get(user.id);
    return { id: user.id, phone: user.phone, name: user.name, role: user.role, sellerStatus: s?.status ?? null, shopName: s?.shopName ?? null };
  });

  // ---------- Catalog ----------
  const productRow = (p) => ({ ...p, wholesale: !!p.wholesale, tiers: q('SELECT min_qty AS minQty, price FROM price_tiers WHERE product_id=? ORDER BY min_qty').all(p.id) });

  r.add('GET', '/api/products', PUB, ({ query }) => {
    const where = ["p.status='active'", "s.status='verified'"], args = [];
    if (query.category) { where.push('p.category=?'); args.push(query.category); }
    if (query.tera) { where.push('p.tera=?'); args.push(query.tera); }
    if (query.wholesale === '1') where.push('p.wholesale=1');
    if (query.q) { where.push('(p.name LIKE ? OR p.name_am LIKE ?)'); args.push(`%${query.q}%`, `%${query.q}%`); }
    const { limit, offset } = page(query);
    const rows = q(`SELECT p.*, s.shop_name AS seller FROM products p JOIN sellers s ON s.user_id=p.seller_id WHERE ${where.join(' AND ')} ORDER BY p.created_at DESC LIMIT ? OFFSET ?`).all(...args, limit, offset);
    return { items: rows.map(productRow), page: Number(query.page || 1) };
  });

  r.add('GET', '/api/products/:id', PUB, ({ params }) => {
    const p = q("SELECT p.*, s.shop_name AS seller FROM products p JOIN sellers s ON s.user_id=p.seller_id WHERE p.id=? AND p.status='active' AND s.status='verified'").get(params.id);
    if (!p) throw new HttpError(404, 'Product not found');
    return productRow(p);
  });

  // ---------- Seller ----------
  r.add('POST', '/api/seller/apply', null, ({ user, body }) => {
    if (user.role === 'admin' || user.role === 'courier') throw new HttpError(403, 'Not allowed for this account type');
    if (q('SELECT 1 FROM sellers WHERE user_id=?').get(user.id)) throw new HttpError(409, 'Already applied');
    q('INSERT INTO sellers(user_id,shop_name,tera,tin,license_no,created_at) VALUES (?,?,?,?,?,?)').run(
      user.id, str(body.shopName, 'shopName', { max: 100 }), str(body.tera, 'tera', { max: 60 }),
      str(body.tin, 'tin', { min: 5, max: 20 }), str(body.licenseNo, 'licenseNo', { min: 3, max: 40 }), Date.now());
    q("UPDATE users SET role='seller' WHERE id=?").run(user.id);
    return { status: 'pending', note: 'An admin will verify your TIN and trade licence.' };
  });

  r.add('POST', '/api/seller/products', ROLE('seller'), ({ user, body }) => {
    const s = q('SELECT status,tera FROM sellers WHERE user_id=?').get(user.id);
    if (!s || s.status !== 'verified') throw new HttpError(403, 'Seller not verified yet');
    const id = uid('p');
    const price = int(body.price, 'price (santim)', { min: 1 }), moq = int(body.moq ?? 1, 'moq', { min: 1 });
    const tiers = Array.isArray(body.tiers) ? body.tiers : [];
    db.exec('BEGIN');
    try {
      q('INSERT INTO products(id,seller_id,name,name_am,category,tera,emoji,description,price,moq,stock,wholesale,created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)').run(
        id, user.id, str(body.name, 'name', { max: 150 }), body.nameAm ? str(body.nameAm, 'nameAm', { max: 150 }) : null,
        str(body.category, 'category', { max: 40 }), s.tera, body.emoji || null, body.description ? str(body.description, 'description', { max: 2000 }) : null,
        price, moq, int(body.stock ?? 0, 'stock'), moq > 1 || tiers.length ? 1 : 0, Date.now());
      for (const t of tiers) q('INSERT INTO price_tiers(product_id,min_qty,price) VALUES (?,?,?)').run(id, int(t.minQty, 'tier.minQty', { min: 1 }), int(t.price, 'tier.price', { min: 1 }));
      db.exec('COMMIT');
    } catch (e) { db.exec('ROLLBACK'); throw e; }
    return productRow(q('SELECT * FROM products WHERE id=?').get(id));
  });

  r.add('GET', '/api/seller/orders', ROLE('seller'), ({ user }) =>
    ({ items: q('SELECT * FROM orders WHERE seller_id=? ORDER BY created_at DESC LIMIT 100').all(user.id).map(svc.view) }));
  r.add('POST', '/api/seller/orders/:id/confirm', ROLE('seller'), ({ user, params }) => svc.sellerStep(user, params.id, 'confirm'));
  r.add('POST', '/api/seller/orders/:id/dispatch', ROLE('seller'), ({ user, params }) => svc.sellerStep(user, params.id, 'out'));

  // ---------- Buyer orders ----------
  r.add('POST', '/api/orders', null, ({ user, body }) => svc.placeOrder(user, body));
  r.add('GET', '/api/orders', null, ({ user }) =>
    ({ items: q('SELECT * FROM orders WHERE buyer_id=? ORDER BY created_at DESC LIMIT 100').all(user.id).map(svc.view) }));
  r.add('GET', '/api/orders/:id', null, ({ user, params }) => {
    const o = svc.getOrder(params.id);
    if (![o.buyer_id, o.seller_id].includes(user.id) && !['admin', 'courier'].includes(user.role)) throw new HttpError(403, 'Forbidden');
    return svc.view(o);
  });
  r.add('POST', '/api/orders/:id/pay', null, ({ user, params }) => svc.startPayment(user, params.id));
  r.add('POST', '/api/orders/:id/cancel', null, ({ user, params }) => svc.cancel(user, params.id));
  r.add('POST', '/api/orders/:id/confirm-receipt', null, ({ user, params }) => svc.confirmReceipt(user, params.id));
  r.add('POST', '/api/orders/:id/dispute', null, ({ user, params, body }) => svc.dispute(user, params.id, body.reason));

  // ---------- Courier ----------
  r.add('POST', '/api/courier/orders/:id/delivered', ROLE('courier', 'admin'), ({ params }) => svc.markDelivered(params.id));
  r.add('GET', '/api/courier/orders', ROLE('courier', 'admin'), () =>
    ({ items: q("SELECT * FROM orders WHERE status='out_for_delivery' ORDER BY created_at LIMIT 100").all().map(svc.view) }));

  // ---------- Dev only: simulate the Chapa checkout. Exists only when CHAPA_MOCK=1 (config forbids that in production) ----------
  r.add('POST', '/api/dev/orders/:id/simulate-payment', null, async ({ user, params }) => {
    if (!config.chapaMock) throw new HttpError(404, 'Not found');
    const o = svc.getOrder(params.id);
    if (o.buyer_id !== user.id) throw new HttpError(403, 'Not your order');
    const pay = q("SELECT * FROM payments WHERE order_id=? AND status='pending' ORDER BY created_at DESC").get(o.id);
    if (!pay) throw new HttpError(409, 'Start payment first');
    chapa._mockPay(pay.tx_ref, (pay.amount / 100).toFixed(2));
    return svc.confirmPayment(pay.tx_ref);
  });

  // ---------- RFQ (wholesale quote requests) ----------
  r.add('POST', '/api/rfqs', null, ({ user, body }) => {
    const id = uid('rfq');
    q('INSERT INTO rfqs(id,buyer_id,product_text,qty,target_price,note,created_at) VALUES (?,?,?,?,?,?,?)').run(
      id, user.id, str(body.product, 'product', { max: 200 }), int(body.qty, 'qty', { min: 1 }), body.targetPrice ? int(body.targetPrice, 'targetPrice', { min: 1 }) : null, body.note ? str(body.note, 'note', { max: 500 }) : null, Date.now());
    return q('SELECT * FROM rfqs WHERE id=?').get(id);
  });
  r.add('GET', '/api/rfqs', null, ({ user }) => ({ items: q('SELECT * FROM rfqs WHERE buyer_id=? ORDER BY created_at DESC').all(user.id) }));
  r.add('GET', '/api/seller/rfqs', ROLE('seller'), () => ({ items: q("SELECT * FROM rfqs WHERE status='open' ORDER BY created_at DESC LIMIT 100").all() }));

  // ---------- Payment webhook (raw body signature) ----------
  r.add('POST', '/api/webhooks/chapa', { public: true, raw: true }, async ({ raw, headers, body }) => {
    if (!chapa.verifySignature(raw, headers)) throw new HttpError(401, 'Bad signature');
    const txRef = body.tx_ref || body.reference;
    if (!txRef) return { received: true };
    const res = await svc.confirmPayment(String(txRef)); // re-verifies with Chapa before crediting
    return { received: true, ...res };
  });

  // ---------- Admin ----------
  r.add('GET', '/api/admin/sellers', ROLE('admin'), ({ query }) =>
    ({ items: q('SELECT s.*, u.phone FROM sellers s JOIN users u ON u.id=s.user_id WHERE s.status=? ORDER BY s.created_at').all(query.status || 'pending') }));
  r.add('POST', '/api/admin/sellers/:id/verify', ROLE('admin'), ({ params, body }) => {
    const status = body.approve === false ? 'rejected' : 'verified';
    if (q('UPDATE sellers SET status=? WHERE user_id=?').run(status, params.id).changes !== 1) throw new HttpError(404, 'Seller not found');
    return { userId: params.id, status };
  });
  r.add('POST', '/api/admin/users/:id/role', ROLE('admin'), ({ params, body }) => {
    if (!['buyer', 'seller', 'courier', 'admin'].includes(body.role)) throw new HttpError(400, 'Invalid role');
    if (q('UPDATE users SET role=? WHERE id=?').run(body.role, params.id).changes !== 1) throw new HttpError(404, 'User not found');
    return { userId: params.id, role: body.role };
  });
  r.add('POST', '/api/admin/orders/:id/resolve', ROLE('admin'), ({ params, body }) => svc.resolveDispute(params.id, body.action));
  r.add('GET', '/api/admin/ledger', ROLE('admin'), () => ({ balances: svc.balances() }));

  return r;
}
