import { hmacHex, safeEqual } from './lib.js';

const BASE = 'https://api.chapa.co/v1';

/** Chapa client. With CHAPA_MOCK=1 it simulates the gateway (dev/tests only). */
export function createChapa(config) {
  const mockPaid = new Map(); // tx_ref -> amount (birr string)

  async function call(path, init = {}) {
    const res = await fetch(`${BASE}${path}`, {
      ...init,
      headers: { Authorization: `Bearer ${config.chapaSecret}`, 'Content-Type': 'application/json' },
    });
    const json = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(`Chapa ${res.status}: ${json.message || 'request failed'}`);
    return json;
  }

  return {
    async initialize({ amountSantim, txRef, phone, firstName, returnUrl, callbackUrl }) {
      const amount = (amountSantim / 100).toFixed(2);
      if (config.chapaMock) return { checkoutUrl: `https://checkout.chapa.co/mock/${txRef}`, amount };
      const json = await call('/transaction/initialize', {
        method: 'POST',
        body: JSON.stringify({
          amount, currency: 'ETB', tx_ref: txRef, phone_number: phone, first_name: firstName,
          return_url: returnUrl, callback_url: callbackUrl,
          customization: { title: 'Merkato Market', description: 'Order payment' },
        }),
      });
      return { checkoutUrl: json.data.checkout_url, amount };
    },

    /** Server-to-server check. Never trust a webhook body alone. */
    async verify(txRef) {
      if (config.chapaMock) {
        const amount = mockPaid.get(txRef);
        return amount ? { status: 'success', amount, currency: 'ETB' } : { status: 'pending' };
      }
      const json = await call(`/transaction/verify/${encodeURIComponent(txRef)}`);
      return { status: json.data?.status, amount: String(json.data?.amount), currency: json.data?.currency };
    },

    /** Chapa signs the payload with HMAC-SHA256; either header may be present. */
    verifySignature(rawBody, headers) {
      const given = headers['x-chapa-signature'] || headers['chapa-signature'];
      if (!given || !config.chapaWebhookSecret) return false;
      if (safeEqual(String(given), hmacHex(config.chapaWebhookSecret, rawBody))) return true;
      try { // fall back to canonical re-serialisation, as in Chapa's Node example
        return safeEqual(String(given), hmacHex(config.chapaWebhookSecret, JSON.stringify(JSON.parse(rawBody))));
      } catch { return false; }
    },

    _mockPay(txRef, amountBirr) { mockPaid.set(txRef, amountBirr); }, // test helper
  };
}
