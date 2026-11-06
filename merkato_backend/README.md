# Merkato Backend

REST API for Merkato Market: phone-OTP auth, verified sellers, catalog with wholesale tiers,
orders, Chapa payments, and a double-entry escrow ledger.

Zero runtime dependencies (Node >= 22.13: built-in `http`, `sqlite`, `crypto`, `fetch`).

## Run
    cp .env.example .env     # then export the variables (or use `node --env-file=.env`)
    npm run seed             # demo sellers + products
    npm start                # http://localhost:3000
    npm test                 # 9 integration tests (payments, escrow, disputes, security)

## Money & escrow model
- All amounts are integer **santim** (1 ETB = 100). Prices, MOQ, tiers and stock are computed **server-side**.
- Online payment (telebirr / CBE Birr / Chapa all go through Chapa checkout):
  `POST /orders` -> `POST /orders/:id/pay` -> buyer pays -> Chapa webhook -> signature check -> **re-verify with Chapa API**
  (status, currency, exact amount) -> funds booked to `escrow`.
- Seller confirms -> dispatches -> courier marks delivered -> buyer confirms receipt (or **auto-release after 5 days**).
- Release: seller gets subtotal minus commission (default 5%); platform gets commission + delivery fee.
- Disputes freeze auto-release until an admin resolves (release or refund). Cancels and refunds are booked as `refund:<buyer>` liabilities.
- Every ledger entry group sums to zero (`GET /api/admin/ledger`).
- One order per seller (client splits the cart by seller).

## Endpoints
| Area | Endpoints |
|---|---|
| Auth | `POST /api/auth/otp`, `POST /api/auth/verify`, `GET /api/me` |
| Catalog | `GET /api/products?q&category&tera&wholesale=1&page`, `GET /api/products/:id` |
| Seller | `POST /api/seller/apply`, `POST /api/seller/products`, `GET /api/seller/orders`, `POST /api/seller/orders/:id/confirm`, `.../dispatch`, `GET /api/seller/rfqs` |
| Orders | `POST /api/orders`, `GET /api/orders`, `GET /api/orders/:id`, `POST .../pay`, `.../cancel`, `.../confirm-receipt`, `.../dispute` |
| Courier | `POST /api/courier/orders/:id/delivered` |
| RFQ | `POST /api/rfqs`, `GET /api/rfqs` |
| Webhook | `POST /api/webhooks/chapa` |
| Admin | `GET /api/admin/sellers`, `POST .../sellers/:id/verify`, `POST .../users/:id/role`, `POST .../orders/:id/resolve`, `GET .../ledger` |

## Before going live (not done yet)
1. Move SQLite -> PostgreSQL (schema is plain SQL); add migrations and backups.
2. Real SMS gateway in `sendSms` (src/app.js); keep OTP out of logs.
3. Test against Chapa **test mode** with real keys (only the mock path is tested here). Confirm in your Chapa dashboard which
   secret/hash is used for webhook signing and set `CHAPA_WEBHOOK_SECRET` accordingly.
4. Refund payouts (`refund:<buyer>` balances) and seller payouts (`seller:<id>` balances) need a payout job (Chapa transfers) + admin screen.
5. Redis-backed rate limiting, request logging, HTTPS/reverse proxy, secrets manager, CORS for web clients.
6. Product images (object storage), seller KYC document upload, courier assignment/tracking, push notifications.
7. Legal/tax: invoicing/VAT and payment-licensing requirements for your setup.
