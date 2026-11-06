import { createApp } from './app.js';

const { server, svc, config } = createApp();
server.listen(config.port, () => console.log(`Merkato API on :${config.port}`));

// Escrow auto-release: delivered orders with no confirmation or dispute after N days.
setInterval(() => { try { const n = svc.autoRelease(); if (n) console.log(`auto-released ${n} order(s)`); } catch (e) { console.error(e); } }, 10 * 60_000).unref();

for (const sig of ['SIGINT', 'SIGTERM']) process.on(sig, () => server.close(() => process.exit(0)));
