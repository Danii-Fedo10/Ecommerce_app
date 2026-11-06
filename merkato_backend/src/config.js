const env = process.env;
const num = (v, d) => (v === undefined || v === '' ? d : Number(v));

export function loadConfig(overrides = {}) {
  const production = env.NODE_ENV === 'production';
  const cfg = {
    production,
    port: num(env.PORT, 3000),
    dbFile: env.DB_FILE || ':memory:',
    jwtSecret: env.JWT_SECRET || (production ? '' : 'dev-only-secret'),
    publicUrl: env.PUBLIC_URL || 'http://localhost:3000',
    adminPhones: (env.ADMIN_PHONES || '').split(',').map((s) => s.trim()).filter(Boolean),
    commissionRate: num(env.COMMISSION_RATE, 0.05),
    standardFee: num(env.STANDARD_FEE_SANTIM, 6000), // 1 birr = 100 santim
    expressFee: num(env.EXPRESS_FEE_SANTIM, 15000),
    autoReleaseDays: num(env.ESCROW_AUTO_RELEASE_DAYS, 5),
    chapaSecret: env.CHAPA_SECRET_KEY || '',
    chapaWebhookSecret: env.CHAPA_WEBHOOK_SECRET || env.CHAPA_SECRET_KEY || '',
    chapaMock: env.CHAPA_MOCK === '1',
    exposeOtp: !production,
    ...overrides,
  };
  if (production && !cfg.jwtSecret) throw new Error('JWT_SECRET is required in production');
  if (production && cfg.chapaMock) throw new Error('CHAPA_MOCK must be off in production');
  return cfg;
}
