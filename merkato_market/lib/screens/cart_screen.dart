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
    return Scaffold(
      appBar: AppBar(title: Text(s.t('cart'))),
      body: s.cart.isEmpty
          ? Center(child: Text(s.t('empty_cart')))
          : ListView(padding: const EdgeInsets.all(12), children: [
              for (final e in s.cart.entries) _line(s, s.byId(e.key), e.value),
              const SizedBox(height: 8),
              _row(s.t('subtotal'), etb(s.subtotal)),
              _row(s.t('delivery'), etb(s.deliveryFee)),
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
