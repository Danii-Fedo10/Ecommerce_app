import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../models.dart';
import '../state/app_state.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  static const _keys = {
    OrderStatus.placed: 'st_placed', OrderStatus.confirmed: 'st_confirmed', OrderStatus.out: 'st_out',
    OrderStatus.delivered: 'st_delivered', OrderStatus.completed: 'st_completed',
  };

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(s.t('orders'))),
      body: s.orders.isEmpty
          ? const Center(child: Text('No orders yet'))
          : ListView(padding: const EdgeInsets.all(12), children: [for (final o in s.orders) _card(context, s, o)]),
    );
  }

  Widget _card(BuildContext context, AppState s, Order o) {
    final escrowHeld = o.payment.escrow && o.status != OrderStatus.completed;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(o.id, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(etb(o.total), style: const TextStyle(fontWeight: FontWeight.bold, color: kGreen)),
          ]),
          Text('${o.payment.label} · ${o.address}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 8),
          for (final l in o.lines) Text('• ${l.name} × ${l.qty}', style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 10),
          for (final st in OrderStatus.values)
            Row(children: [
              Icon(st.index <= o.status.index ? Icons.check_circle : Icons.radio_button_unchecked, size: 18, color: st.index <= o.status.index ? kGreen : Colors.grey),
              const SizedBox(width: 8),
              Text(s.t(_keys[st]!), style: TextStyle(fontWeight: st == o.status ? FontWeight.bold : null)),
            ]),
          if (escrowHeld)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text('🔒 Payment held in escrow', style: TextStyle(fontSize: 12, color: Colors.orange.shade800))),
          const SizedBox(height: 8),
          if (o.status == OrderStatus.delivered)
            FilledButton(onPressed: () => s.advance(o), child: const Text('Confirm receipt & release payment'))
          else if (o.status != OrderStatus.completed)
            // Demo only: real transitions come from seller / courier events (push + webhook).
            TextButton(onPressed: () => s.advance(o), child: const Text('Simulate next step (demo)')),
        ]),
      ),
    );
  }
}
