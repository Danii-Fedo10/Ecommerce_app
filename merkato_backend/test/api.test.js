import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createApp } from '../src/app.js';
import { hmacHex } from '../src/lib.js';

const SECRET = 'whsec_test';
let app, base;
const api = async (method, path, { token, body, headers = {}, rawBody } = {}) => {
  const res = await fetch(base + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}), ...headers },
    body: rawBody ?? (body ? JSON.stringify(body) : undefined),
  });
  return { status: res.status, json: await res.json() };
};
const login = async (phone) => {
  const otp = await api('POST', '/api/auth/otp', { body: { phone } });
  const v = await api('POST', '/api/auth/verify', { body: { phone, code: otp.json.devCode, name: 'Test' } });
  return v.json;
};
const address = { name: 'Dawit Bekele', phone: '0911223344', subcity: 'Bole', landmark: 'Behind Edna Mall, blue gate' };
const webhook = (txRef, sig) => {
  const rawBody = JSON.stringify({ event: 'charge.success', tx_ref: txRef, status: 'success' });
  return api('POST', '/api/webhooks/chapa', { rawBody, headers: { 'x-chapa-signature': sig ?? hmacHex(SECRET, rawBody) } });
};

let admin, seller, courier, buyer, product, tiered;

before(async () => {
  app = createApp({ config: { chapaMock: true, chapaWebhookSecret: SECRET, adminPhones: ['+251900000000'], commissionRate: 0.05, standardFee: 6000, expressFee: 15000 } });
  await new Promise((r) => app.server.listen(0, r));
  base = `http://127.0.0.1:${app.server.address().port}`;

  admin = await login('0900000000');
  seller = await login('0911000001');
  courier = await login('0911000002');
  buyer = await login('0922000001');
  assert.equal(admin.user.role, 'admin');

  await api('POST', '/api/admin/users/' + courier.user.id + '/role', { token: admin.token, body: { role: 'courier' } });
  const apply = await api('POST', '/api/seller/apply', { token: seller.token, body: { shopName: 'Gesho Tera Wholesale', tera: 'Gesho Tera', tin: '0012345678', licenseNo: 'AA/123/2018' } });
  assert.equal(apply.json.status, 'pending');
  // Unverified seller cannot list
  assert.equal((await api('POST', '/api/seller/products', { token: seller.token, body: { name: 'X', category: 'grain', price: 100 } })).status, 403);
  await api('POST', '/api/admin/sellers/' + seller.user.id + '/verify', { token: admin.token, body: {} });
  // seller token still has role claim 'buyer' at signing time; role is re-read from DB, so it works:
  product = (await api('POST', '/api/seller/products', { token: seller.token, body: { name: 'Gesho 1kg', category: 'grain', price: 26000, stock: 100, moq: 10, tiers: [{ minQty: 10, price: 26000 }, { minQty: 50, price: 23500 }] } })).json;
  tiered = product;
});
after(() => app.server.close());

test('catalog lists verified-seller products with tiers', async () => {
  const r = await api('GET', '/api/products?wholesale=1');
  assert.equal(r.json.items.length, 1);
  assert.equal(r.json.items[0].tiers.length, 2);
});

test('auth required; roles enforced', async () => {
  assert.equal((await api('GET', '/api/orders')).status, 401);
  assert.equal((await api('POST', '/api/courier/orders/x/delivered', { token: buyer.token })).status, 403);
  assert.equal((await api('GET', '/api/admin/ledger', { token: buyer.token })).status, 403);
});

test('server enforces MOQ, stock, and own-product rule', async () => {
  const mk = (qty, token = buyer.token) => api('POST', '/api/orders', { token, body: { items: [{ productId: product.id, qty }], address, paymentMethod: 'cod' } });
  assert.equal((await mk(5)).status, 400);        // below MOQ
  assert.equal((await mk(1000)).status, 409);     // over stock
  assert.equal((await mk(10, seller.token)).status, 400); // own product
});

test('online payment -> escrow -> delivery -> release with commission', async () => {
  const o = (await api('POST', '/api/orders', { token: buyer.token, body: { items: [{ productId: product.id, qty: 50 }], address, paymentMethod: 'telebirr' } })).json;
  assert.equal(o.subtotal, 50 * 23500);          // tier price applied server-side
  assert.equal(o.total, 50 * 23500 + 6000);
  assert.equal(o.status, 'pending_payment');

  const pay = (await api('POST', `/api/orders/${o.id}/pay`, { token: buyer.token })).json;
  assert.match(pay.checkoutUrl, /chapa/);

  // forged webhook rejected
  assert.equal((await webhook(pay.txRef, 'deadbeef')).status, 401);
  // valid signature but Chapa has not confirmed payment -> no credit
  const early = await webhook(pay.txRef);
  assert.equal(early.json.ok, false);
  assert.equal((await api('GET', `/api/orders/${o.id}`, { token: buyer.token })).json.status, 'pending_payment');

  app.chapa._mockPay(pay.txRef, (o.total / 100).toFixed(2));
  assert.equal((await webhook(pay.txRef)).json.ok, true);
  assert.equal((await webhook(pay.txRef)).json.duplicate, true); // idempotent
  assert.equal((await api('GET', `/api/orders/${o.id}`, { token: buyer.token })).json.status, 'placed');
  assert.equal(app.svc.balances().escrow >= o.total, true);

  assert.equal((await api('POST', `/api/seller/orders/${o.id}/confirm`, { token: seller.token })).json.status, 'confirmed');
  assert.equal((await api('POST', `/api/seller/orders/${o.id}/dispatch`, { token: seller.token })).json.status, 'out_for_delivery');
  assert.equal((await api('POST', `/api/courier/orders/${o.id}/delivered`, { token: courier.token })).json.status, 'delivered');

  const before = app.svc.balances();
  assert.equal((await api('POST', `/api/orders/${o.id}/confirm-receipt`, { token: buyer.token })).json.status, 'completed');
  const after = app.svc.balances();
  const commission = Math.round(o.subtotal * 0.05);
  assert.equal(after[`seller:${seller.user.id}`], o.subtotal - commission);
  assert.equal(after.platform - (before.platform || 0), commission + 6000);
  assert.equal(Object.values(after).reduce((a, b) => a + b, 0), 0); // ledger always balances
});

test('amount mismatch is flagged and never credited', async () => {
  const o = (await api('POST', '/api/orders', { token: buyer.token, body: { items: [{ productId: product.id, qty: 10 }], address, paymentMethod: 'chapa' } })).json;
  const pay = (await api('POST', `/api/orders/${o.id}/pay`, { token: buyer.token })).json;
  app.chapa._mockPay(pay.txRef, '1.00');
  assert.equal((await webhook(pay.txRef)).json.reason, 'amount mismatch');
  assert.equal((await api('GET', `/api/orders/${o.id}`, { token: buyer.token })).json.status, 'pending_payment');
});

test('cancel paid order -> refund due; stock restored', async () => {
  const stock = () => app.db.prepare('SELECT stock FROM products WHERE id=?').get(product.id).stock;
  const s0 = stock();
  const o = (await api('POST', '/api/orders', { token: buyer.token, body: { items: [{ productId: product.id, qty: 10 }], address, paymentMethod: 'telebirr' } })).json;
  assert.equal(stock(), s0 - 10);
  const pay = (await api('POST', `/api/orders/${o.id}/pay`, { token: buyer.token })).json;
  app.chapa._mockPay(pay.txRef, (o.total / 100).toFixed(2));
  await webhook(pay.txRef);
  const c = await api('POST', `/api/orders/${o.id}/cancel`, { token: buyer.token });
  assert.equal(c.json.payment_status, 'refund_due');
  assert.equal(stock(), s0);
  assert.equal(app.svc.balances()[`refund:${buyer.user.id}`], o.total);
});

test('COD flow + dispute blocks auto-release; admin refunds', async () => {
  const o = (await api('POST', '/api/orders', { token: buyer.token, body: { items: [{ productId: product.id, qty: 10 }], address, paymentMethod: 'cod' } })).json;
  assert.equal(o.status, 'placed');
  await api('POST', `/api/seller/orders/${o.id}/confirm`, { token: seller.token });
  await api('POST', `/api/seller/orders/${o.id}/dispatch`, { token: seller.token });
  await api('POST', `/api/courier/orders/${o.id}/delivered`, { token: courier.token });
  assert.equal((await api('POST', `/api/orders/${o.id}/dispute`, { token: buyer.token, body: { reason: 'Wrong item delivered' } })).json.status, 'disputed');
  assert.equal(app.svc.autoRelease(Date.now() + 30 * 86_400_000) >= 0, true);
  assert.equal(app.svc.getOrder(o.id).status, 'disputed'); // still blocked
  assert.equal((await api('POST', `/api/admin/orders/${o.id}/resolve`, { token: admin.token, body: { action: 'refund' } })).json.status, 'refunded');
});

test('auto-release after 5 days when buyer is silent', async () => {
  const o = (await api('POST', '/api/orders', { token: buyer.token, body: { items: [{ productId: product.id, qty: 10 }], address, paymentMethod: 'cod' } })).json;
  await api('POST', `/api/seller/orders/${o.id}/confirm`, { token: seller.token });
  await api('POST', `/api/seller/orders/${o.id}/dispatch`, { token: seller.token });
  await api('POST', `/api/courier/orders/${o.id}/delivered`, { token: courier.token });
  assert.equal(app.svc.autoRelease(Date.now() + 4 * 86_400_000), 0);
  assert.equal(app.svc.autoRelease(Date.now() + 6 * 86_400_000), 1);
  assert.equal(app.svc.getOrder(o.id).status, 'completed');
});

test('OTP: wrong code rejected; address validation', async () => {
  await api('POST', '/api/auth/otp', { body: { phone: '0933000009' } });
  assert.equal((await api('POST', '/api/auth/verify', { body: { phone: '0933000009', code: '000000' } })).status, 401);
  assert.equal((await api('POST', '/api/auth/otp', { body: { phone: '12345' } })).status, 400);
  const bad = await api('POST', '/api/orders', { token: buyer.token, body: { items: [{ productId: product.id, qty: 10 }], address: { ...address, landmark: 'x' }, paymentMethod: 'cod' } });
  assert.equal(bad.status, 400);
});
