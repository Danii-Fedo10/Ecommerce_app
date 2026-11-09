import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../models.dart';
import '../state/app_state.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final groups = s.cartBySeller;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('cart'))),
      body: groups.isEmpty
          ? Center(child: Text(s.t('empty_cart')))
          : ListView(padding: const EdgeInsets.all(12), children: [
              if (groups.length > 1)
                Container(
                  margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: kYellow.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(10)),
                  child: Text('Items from ${groups.length} sellers will be placed as ${groups.length} separate orders, each with its own delivery.', style: const TextStyle(fontSize: 12)),
                ),
              for (final g in groups.values) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                  child: Row(children: [const Icon(Icons.store, size: 16, color: kGreen), const SizedBox(width: 6), Text(g.first.key.seller, style: const TextStyle(fontWeight: FontWeight.bold))]),
                ),
                for (final e in g) _line(s, e.key, e.value),
              ],
              const SizedBox(height: 8),
              _row(s.t('subtotal'), etb(s.subtotal)),
              _row('${s.t('delivery')} (estimate)', etb(s.deliveryFee)),
              const Divider(),
              _row(s.t('total'), etb(s.total), bold: true),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen())), child: Text(s.t('checkout'))),
            ]),
    );
  }

  Widget _row(String a, String b, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(a, style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
          Text(b, style: TextStyle(fontWeight: bold ? FontWeight.bold : null, color: bold ? kGreen : null)),
        ]),
      );

  Widget _line(AppState s, Product p, int qty) => Card(
        child: ListTile(
          leading: Text(p.emoji, style: const TextStyle(fontSize: 32)),
          title: Text(s.pname(p), maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${etb(s.unitPrice(p, qty))} × $qty   (${s.t('moq')} ${p.moq})'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => s.setQty(p, qty > p.moq ? qty - 1 : 0)),
            Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => s.setQty(p, qty + 1)),
          ]),
        ),
      );
}
