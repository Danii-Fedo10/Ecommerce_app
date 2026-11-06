import crypto from 'node:crypto';
import { HttpError, uid, int, str } from './lib.js';

const SUBCITIES = ['Addis Ketema', 'Arada', 'Bole', 'Gullele', 'Kirkos', 'Kolfe Keranio', 'Lideta', 'Nifas Silk-Lafto', 'Yeka', 'Akaki Kaliti', 'Lemi Kura', 'Other'];
const ONLINE = ['telebirr', 'cbe_birr', 'chapa'];
const DAY = 86_400_000;

export function createServices({ db, config, chapa }) {
  const q = (sql) => db.prepare(sql);

  function tx(fn) {
    db.exec('BEGIN IMMEDIATE');
    try { const r = fn(); db.exec('COMMIT'); return r; } catch (e) { db.exec('ROLLBACK'); throw e; }
  }

  // ---- Ledger (double entry; each group must net to zero) ----
  function post(orderId, kind, entries) {
    if (entries.reduce((s, [, a]) => s + a, 0) !== 0) throw new Error(`Unbalanced ledger entry: ${kind}`);
    const group = uid('lg'), now = Date.now();
    for (const [account, amount] of entries) {
      if (amount !== 0) q('INSERT INTO ledger(entry_group,order_id,kind,account,amount,created_at) VALUES (?,?,?,?,?,?)').run(group, orderId, kind, account, amount, now);
    }
  }

  function getOrder(id) {
    const o = q('SELECT * FROM orders WHERE id=?').get(id);
    if (!o) throw new HttpError(404, 'Order not found');
    return o;
  }

  function view(o) {
    return { ...o, address: JSON.parse(o.address), items: q('SELECT product_id AS productId,name,qty,unit_price AS unitPrice FROM order_items WHERE order_id=?').all(o.id) };
  }

  function unitPrice(product, qty) {
    let price = product.price;
    for (const t of q('SELECT * FROM price_tiers WHERE product_id=? ORDER BY min_qty').all(product.id)) if (qty >= t.min_qty) price = t.price;
    return price;
  }

  function parseAddress(a = {}) {
    const phone = str(a.phone, 'address.phone', { min: 9, max: 16 });
    return {
      name: str(a.name, 'address.name', { min: 3, max: 80 }), phone,
      subcity: SUBCITIES.includes(a.subcity) ? a.subcity : (() => { throw new HttpError(400, 'Invalid sub-city'); })(),
      landmark: str(a.landmark, 'address.landmark', { min: 6, max: 300 }), // landmark-first addressing
      lat: typeof a.lat === 'number' ? a.lat : null, lng: typeof a.lng === 'number' ? a.lng : null,
    };
  }

  // ---- Orders ----
  /** Prices, MOQ and stock are always computed server-side; the client only sends ids + quantities. */
  function placeOrder(user, body) {
    const items = Array.isArray(body.items) ? body.items : [];
    if (!items.length || items.length > 50) throw new HttpError(400, 'items required (max 50)');
    const method = body.paymentMethod;
    if (!['cod', ...ONLINE].includes(method)) throw new HttpError(400, 'Invalid paymentMethod');
    const address = parseAddress(body.address);

    return tx(() => {
      let sellerId = null, subtotal = 0;
      const lines = [];
      for (const it of items) {
        const qty = int(it.qty, 'qty', { min: 1, max: 100000 });
        const p = q("SELECT * FROM products WHERE id=? AND status='active'").get(String(it.productId));
        if (!p) throw new HttpError(404, `Product ${it.productId} not found`);
        if (sellerId && sellerId !== p.seller_id) throw new HttpError(400, 'One order per seller: split your cart by seller');
        sellerId = p.seller_id;
        if (p.seller_id === user.id) throw new HttpError(400, 'You cannot buy your own product');
        if (qty < p.moq) throw new HttpError(400, `Minimum order for "${p.name}" is ${p.moq}`);
        const res = q('UPDATE products SET stock=stock-? WHERE id=? AND stock>=?').run(qty, p.id, qty);
        if (res.changes !== 1) throw new HttpError(409, `Not enough stock for "${p.name}"`);
        const unit = unitPrice(p, qty);
        subtotal += unit * qty;
        lines.push({ p, qty, unit });
      }
      const delivery = body.express ? config.expressFee : config.standardFee;
      const id = `MK-${crypto.randomBytes(4).toString('hex').toUpperCase()}`;
      const status = method === 'cod' ? 'placed' : 'pending_payment';
      q('INSERT INTO orders(id,buyer_id,seller_id,status,payment_method,payment_status,subtotal,delivery_fee,total,address,created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?)')
        .run(id, user.id, sellerId, status, method, method === 'cod' ? 'cod' : 'unpaid', subtotal, delivery, subtotal + delivery, JSON.stringify(address), Date.now());
      for (const l of lines) q('INSERT INTO order_items(order_id,product_id,name,qty,unit_price) VALUES (?,?,?,?,?)').run(id, l.p.id, l.p.name, l.qty, l.unit);
      return view(getOrder(id));
    });
  }

  async function startPayment(user, orderId) {
    const o = getOrder(orderId);
    if (o.buyer_id !== user.id) throw new HttpError(403, 'Not your order');
    if (!ONLINE.includes(o.payment_method) || o.status !== 'pending_payment') throw new HttpError(409, 'Order is not awaiting online payment');
    const txRef = `mk-${o.id}-${crypto.randomBytes(3).toString('hex')}`;
    q('INSERT INTO payments(tx_ref,order_id,provider,amount,created_at) VALUES (?,?,?,?,?)').run(txRef, o.id, 'chapa', o.total, Date.now());
    const r = await chapa.initialize({
      amountSantim: o.total, txRef, phone: user.phone, firstName: user.name || 'Customer',
      returnUrl: `${config.publicUrl}/payment/return?order=${o.id}`, callbackUrl: `${config.publicUrl}/api/webhooks/chapa`,
    });
    return { txRef, checkoutUrl: r.checkoutUrl };
  }

  /** Idempotent. Funds move into escrow only after server-side verification with Chapa. */
  async function confirmPayment(txRef) {
    const pay = q('SELECT * FROM payments WHERE tx_ref=?').get(txRef);
    if (!pay) return { ok: false, reason: 'unknown tx_ref' };
    if (pay.status === 'paid') return { ok: true, duplicate: true };
    const v = await chapa.verify(txRef);
    if (v.status !== 'success') return { ok: false, reason: 'not successful yet' };
    if (v.currency !== 'ETB' || Math.round(Number(v.amount) * 100) !== pay.amount) {
      q("UPDATE payments SET status='flagged' WHERE tx_ref=?").run(txRef); // amount mismatch: needs a human
      return { ok: false, reason: 'amount mismatch' };
    }
    tx(() => {
      const fresh = q('SELECT status FROM payments WHERE tx_ref=?').get(txRef);
      if (fresh.status === 'paid') return;
      q("UPDATE payments SET status='paid' WHERE tx_ref=?").run(txRef);
      const o = getOrder(pay.order_id);
      if (o.status !== 'pending_payment') { // e.g. cancelled while paying: refund
        post(o.id, 'late_payment_refund_due', [['external', -pay.amount], [`refund:${o.buyer_id}`, pay.amount]]);
        return;
      }
      q("UPDATE orders SET status='placed', payment_status='escrow' WHERE id=?").run(o.id);
      post(o.id, 'payment_received', [['external', -pay.amount], ['escrow', pay.amount]]);
    });
    return { ok: true };
  }

  function restock(orderId) {
    for (const it of q('SELECT product_id,qty FROM order_items WHERE order_id=?').all(orderId)) q('UPDATE products SET stock=stock+? WHERE id=?').run(it.qty, it.product_id);
  }

  function cancel(user, orderId) {
    return tx(() => {
      const o = getOrder(orderId);
      if (o.buyer_id !== user.id) throw new HttpError(403, 'Not your order');
      if (!['pending_payment', 'placed'].includes(o.status)) throw new HttpError(409, 'Order can no longer be cancelled');
      restock(o.id);
      if (o.payment_status === 'escrow') {
        post(o.id, 'refund_due', [['escrow', -o.total], [`refund:${o.buyer_id}`, o.total]]);
        q("UPDATE orders SET status='cancelled', payment_status='refund_due' WHERE id=?").run(o.id);
      } else q("UPDATE orders SET status='cancelled' WHERE id=?").run(o.id);
      return view(getOrder(o.id));
    });
  }

  const flow = { confirm: ['placed', 'confirmed'], out: ['confirmed', 'out_for_delivery'] };

  function sellerStep(user, orderId, step) {
    return tx(() => {
      const o = getOrder(orderId);
      if (o.seller_id !== user.id) throw new HttpError(403, 'Not your order');
      if (o.status !== flow[step][0]) throw new HttpError(409, `Order must be "${flow[step][0]}"`);
      q('UPDATE orders SET status=? WHERE id=?').run(flow[step][1], o.id);
      return view(getOrder(o.id));
    });
  }

  function markDelivered(orderId) {
    return tx(() => {
      const o = getOrder(orderId);
      if (o.status !== 'out_for_delivery') throw new HttpError(409, 'Order is not out for delivery');
      const now = Date.now();
      q("UPDATE orders SET status='delivered', delivered_at=?, auto_release_at=? WHERE id=?").run(now, now + config.autoReleaseDays * DAY, o.id);
      if (o.payment_method === 'cod') post(o.id, 'cod_collected', [['external', -o.total], ['courier_cash', o.total]]);
      return view(getOrder(o.id));
    });
  }

  /** Pays out the seller (minus commission) and books delivery fee + commission to the platform. */
  function release(orderId) {
    return tx(() => {
      const o = getOrder(orderId);
      if (!['delivered', 'disputed'].includes(o.status)) throw new HttpError(409, 'Order is not releasable');
      const source = o.payment_method === 'cod' ? 'courier_cash' : 'escrow';
      const commission = Math.round(o.subtotal * config.commissionRate);
      post(o.id, 'escrow_release', [[source, -o.total], [`seller:${o.seller_id}`, o.subtotal - commission], ['platform', commission + o.delivery_fee]]);
      q("UPDATE orders SET status='completed', payment_status='released' WHERE id=?").run(o.id);
      return view(getOrder(o.id));
    });
  }

  function confirmReceipt(user, orderId) {
    const o = getOrder(orderId);
    if (o.buyer_id !== user.id) throw new HttpError(403, 'Not your order');
    if (o.status !== 'delivered') throw new HttpError(409, 'Order is not delivered');
    return release(orderId);
  }

  function dispute(user, orderId, reason) {
    const o = getOrder(orderId);
    if (o.buyer_id !== user.id) throw new HttpError(403, 'Not your order');
    if (o.status !== 'delivered') throw new HttpError(409, 'Only delivered orders can be disputed');
    q("UPDATE orders SET status='disputed', dispute_reason=?, auto_release_at=NULL WHERE id=?").run(str(reason, 'reason', { min: 5, max: 500 }), o.id);
    return view(getOrder(o.id));
  }

  function resolveDispute(orderId, action) {
    const o = getOrder(orderId);
    if (o.status !== 'disputed') throw new HttpError(409, 'Order is not disputed');
    if (action === 'release') return release(orderId);
    if (action !== 'refund') throw new HttpError(400, 'action must be release or refund');
    return tx(() => {
      const source = o.payment_method === 'cod' ? 'courier_cash' : 'escrow';
      post(o.id, 'refund_due', [[source, -o.total], [`refund:${o.buyer_id}`, o.total]]);
      q("UPDATE orders SET status='refunded', payment_status='refund_due' WHERE id=?").run(o.id);
      return view(getOrder(o.id));
    });
  }

  /** Called on a timer: delivered orders with no confirmation/dispute auto-release after N days. */
  function autoRelease(nowMs = Date.now()) {
    const due = q("SELECT id FROM orders WHERE status='delivered' AND auto_release_at IS NOT NULL AND auto_release_at<=?").all(nowMs);
    due.forEach((d) => release(d.id));
    return due.length;
  }

  function balances() {
    return Object.fromEntries(q('SELECT account, SUM(amount) AS balance FROM ledger GROUP BY account').all().map((r) => [r.account, r.balance]));
  }

  return { tx, getOrder, view, placeOrder, startPayment, confirmPayment, cancel, sellerStep, markDelivered, confirmReceipt, release, dispute, resolveDispute, autoRelease, balances, unitPrice };
}
