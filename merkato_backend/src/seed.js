import { openDb } from './db.js';
import { loadConfig } from './config.js';
import { uid } from './lib.js';

const config = loadConfig();
const db = openDb(config.dbFile);
const now = Date.now();
const sellers = [
  ['+251911000001', 'Abeba Coffee Traders', 'Addis Ketema'],
  ['+251911000002', 'Tigist Shema', 'Shema Tera'],
  ['+251911000003', 'Gesho Tera Wholesale', 'Gesho Tera'],
];
const products = [
  [0, 'Yirgacheffe Coffee 1kg', 'coffee', '☕', 120000, 1, 200, []],
  [1, 'Habesha Kemis (Hand-woven)', 'fashion', '👗', 450000, 1, 30, []],
  [2, 'Gesho (Hops) Leaves 1kg', 'grain', '🌿', 26000, 10, 5000, [[10, 26000], [50, 23500], [200, 21000]]],
];
const ids = sellers.map(([phone, shop, tera]) => {
  const id = uid('u');
  db.prepare("INSERT OR IGNORE INTO users(id,phone,name,role,created_at) VALUES (?,?,?, 'seller', ?)").run(id, phone, shop, now);
  const u = db.prepare('SELECT id FROM users WHERE phone=?').get(phone);
  db.prepare("INSERT OR IGNORE INTO sellers(user_id,shop_name,tera,tin,license_no,status,created_at) VALUES (?,?,?,?,?,'verified',?)").run(u.id, shop, tera, '0000000000', 'DEMO-LICENCE', now);
  return { id: u.id, tera };
});
for (const [si, name, cat, emoji, price, moq, stock, tiers] of products) {
  const pid = uid('p');
  db.prepare('INSERT INTO products(id,seller_id,name,category,tera,emoji,price,moq,stock,wholesale,created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?)')
    .run(pid, ids[si].id, name, cat, ids[si].tera, emoji, price, moq, stock, moq > 1 ? 1 : 0, now);
  for (const [min, p] of tiers) db.prepare('INSERT INTO price_tiers(product_id,min_qty,price) VALUES (?,?,?)').run(pid, min, p);
}
console.log('Seeded demo sellers and products into', config.dbFile);
