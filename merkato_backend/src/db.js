import { DatabaseSync } from 'node:sqlite';

// All money is stored as integer santim (1 ETB = 100 santim) to avoid float errors.
// SQLite keeps this reference build dependency-free; the schema is plain SQL and ports to PostgreSQL.
const SCHEMA = `
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY, phone TEXT UNIQUE NOT NULL, name TEXT,
  role TEXT NOT NULL DEFAULT 'buyer' CHECK (role IN ('buyer','seller','courier','admin')),
  created_at INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS otps (
  phone TEXT PRIMARY KEY, code_hash TEXT NOT NULL, expires_at INTEGER NOT NULL, attempts INTEGER NOT NULL DEFAULT 0);
CREATE TABLE IF NOT EXISTS sellers (
  user_id TEXT PRIMARY KEY REFERENCES users(id), shop_name TEXT NOT NULL, tera TEXT NOT NULL,
  tin TEXT NOT NULL, license_no TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','verified','rejected')), created_at INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS products (
  id TEXT PRIMARY KEY, seller_id TEXT NOT NULL REFERENCES users(id),
  name TEXT NOT NULL, name_am TEXT, category TEXT NOT NULL, tera TEXT NOT NULL, emoji TEXT, description TEXT,
  price INTEGER NOT NULL CHECK (price > 0), moq INTEGER NOT NULL DEFAULT 1 CHECK (moq >= 1),
  stock INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0), wholesale INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'active', created_at INTEGER NOT NULL);
CREATE INDEX IF NOT EXISTS idx_products_cat ON products(category, tera);
CREATE TABLE IF NOT EXISTS price_tiers (
  product_id TEXT NOT NULL REFERENCES products(id), min_qty INTEGER NOT NULL, price INTEGER NOT NULL,
  PRIMARY KEY (product_id, min_qty));
CREATE TABLE IF NOT EXISTS orders (
  id TEXT PRIMARY KEY, buyer_id TEXT NOT NULL REFERENCES users(id), seller_id TEXT NOT NULL REFERENCES users(id),
  status TEXT NOT NULL, payment_method TEXT NOT NULL, payment_status TEXT NOT NULL,
  subtotal INTEGER NOT NULL, delivery_fee INTEGER NOT NULL, total INTEGER NOT NULL,
  address TEXT NOT NULL, created_at INTEGER NOT NULL, delivered_at INTEGER, auto_release_at INTEGER, dispute_reason TEXT);
CREATE INDEX IF NOT EXISTS idx_orders_buyer ON orders(buyer_id);
CREATE INDEX IF NOT EXISTS idx_orders_seller ON orders(seller_id);
CREATE TABLE IF NOT EXISTS order_items (
  order_id TEXT NOT NULL REFERENCES orders(id), product_id TEXT NOT NULL REFERENCES products(id),
  name TEXT NOT NULL, qty INTEGER NOT NULL, unit_price INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS payments (
  tx_ref TEXT PRIMARY KEY, order_id TEXT NOT NULL REFERENCES orders(id), provider TEXT NOT NULL,
  amount INTEGER NOT NULL, status TEXT NOT NULL DEFAULT 'pending', created_at INTEGER NOT NULL);
-- Double-entry ledger: every entry group sums to zero. Source of truth for who is owed what.
CREATE TABLE IF NOT EXISTS ledger (
  id INTEGER PRIMARY KEY AUTOINCREMENT, entry_group TEXT NOT NULL, order_id TEXT, kind TEXT NOT NULL,
  account TEXT NOT NULL, amount INTEGER NOT NULL, created_at INTEGER NOT NULL);
CREATE INDEX IF NOT EXISTS idx_ledger_account ON ledger(account);
CREATE TABLE IF NOT EXISTS rfqs (
  id TEXT PRIMARY KEY, buyer_id TEXT NOT NULL REFERENCES users(id), product_text TEXT NOT NULL,
  qty INTEGER NOT NULL, target_price INTEGER, note TEXT, status TEXT NOT NULL DEFAULT 'open', created_at INTEGER NOT NULL);
`;

export function openDb(file = ':memory:') {
  const db = new DatabaseSync(file);
  db.exec('PRAGMA journal_mode = WAL; PRAGMA foreign_keys = ON;');
  db.exec(SCHEMA);
  return db;
}
