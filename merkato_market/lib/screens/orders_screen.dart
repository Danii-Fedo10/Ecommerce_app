import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../models.dart';
import '../state/app_state.dart';
import 'login_screen.dart';

const _flow = ['placed', 'confirmed', 'out_for_delivery', 'delivered', 'completed'];
const _keys = {
  'pending_payment': 'st_pending_payment', 'placed': 'st_placed', 'confirmed': 'st_confirmed', 'out_for_delivery': 'st_out',
  'delivered': 'st_delivered', 'completed': 'st_completed', 'cancelled': 'st_cancelled', 'disputed': 'st_disputed', 'refunded': 'st_refunded',
};

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (!s.loggedIn) return _signIn(context, s);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('orders'))),
      body: RefreshIndicator(
        onRefresh: s.loadOrders,
        child: s.orders.isEmpty
            ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [SizedBox(height: 160), Center(child: Text('No orders yet'))])
            : ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(12), children: [for (final o in s.orders) _card(context, s, o)]),
      ),
    );
  }

  Widget _signIn(BuildContext context, AppState s) => Scaffold(
        appBar: AppBar(title: Text(s.t('orders'))),
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Sign in to see your orders'),
          const SizedBox(height: 10),
          FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())), child: const Text('Sign in')),
        ])),
      );

  Future<void> _run(BuildContext context, Future<void> Function() fn) async {
    final messenger = ScaffoldMessenger.of(context);
    try { await fn(); } catch (e) { messenger.showSnackBar(SnackBar(content: Text(errText(e)))); }
  }

  Future<void> _disputeDialog(BuildContext context, AppState s, Order o) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report a problem'),
        content: TextField(controller: reason, maxLines: 3, decoration: const InputDecoration(hintText: 'What went wrong? (min 5 characters)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
        ],
      ),
    );
    if (ok == true && context.mounted) await _run(context, () => s.disputeOrder(o.id, reason.text));
  }

  Widget _card(BuildContext context, AppState s, Order o) {
    final inFlow = _flow.contains(o.status);
    final idx = _flow.indexOf(o.status);
    final escrowHeld = o.paymentStatus == 'escrow';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(o.id, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(etb(o.total), style: const TextStyle(fontWeight: FontWeight.bold, color: kGreen)),
          ]),
          Text('${o.paymentLabel} · ${o.address}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 8),
          for (final l in o.lines) Text('• ${l.name} × ${l.qty}  (${etb(l.unit)} each)', style: const TextStyle(fontSize: 13)),
          Text('${s.t('delivery')}: ${etb(o.delivery)}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 10),
          if (inFlow)
            for (var i = 0; i < _flow.length; i++)
              Row(children: [
                Icon(i <= idx ? Icons.check_circle : Icons.radio_button_unchecked, size: 18, color: i <= idx ? kGreen : Colors.grey),
                const SizedBox(width: 8),
                Text(s.t(_keys[_flow[i]]!), style: TextStyle(fontWeight: i == idx ? FontWeight.bold : null)),
              ])
          else
            Chip(label: Text(s.t(_keys[o.status] ?? o.status)), backgroundColor: o.status == 'cancelled' || o.status == 'refunded' ? kRed.withValues(alpha: 0.12) : kYellow.withValues(alpha: 0.3)),
          if (escrowHeld) Padding(padding: const EdgeInsets.only(top: 8), child: Text('🔒 Payment held in escrow until you confirm delivery', style: TextStyle(fontSize: 12, color: Colors.orange.shade800))),
          if (o.paymentStatus == 'refund_due') const Padding(padding: EdgeInsets.only(top: 8), child: Text('Refund is being processed', style: TextStyle(fontSize: 12, color: kRed))),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            if (o.status == 'pending_payment' && !o.isCod) FilledButton(onPressed: () => _run(context, () => s.payOrder(o.id)), child: const Text('Pay now')),
            if (o.status == 'pending_payment' || o.status == 'placed') OutlinedButton(onPressed: () => _run(context, () => s.cancelOrder(o.id)), child: const Text('Cancel order')),
            if (o.status == 'delivered') FilledButton(onPressed: () => _run(context, () => s.confirmReceipt(o.id)), child: const Text('Confirm receipt')),
            if (o.status == 'delivered') OutlinedButton(onPressed: () => _disputeDialog(context, s, o), child: const Text('Report a problem')),
          ]),
        ]),
      ),
    );
  }
}
