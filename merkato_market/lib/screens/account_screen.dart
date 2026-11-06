import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../data/mock_data.dart';
import '../models.dart';
import '../state/app_state.dart';

const kMyShop = 'My Merkato Shop';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final mine = s.products.where((p) => p.seller == kMyShop).toList();
    final revenue = s.orders.fold(0.0, (a, o) => a + o.subtotal);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('account'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(radius: 28, child: Icon(Icons.person)), title: Text('Guest user'), subtitle: Text('Sign in with phone number (OTP)')),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: s.am, onChanged: (_) => s.toggleLang(), title: const Text('አማርኛ / Amharic')),
        ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.favorite_border), title: const Text('Wishlist'), trailing: Text('${s.wishlist.length}')),
        const Divider(height: 30),
        Row(children: [
          const Text('Seller dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Spacer(),
          FilledButton.icon(onPressed: () => _addProduct(context, s), icon: const Icon(Icons.add), label: const Text('Add product')),
        ]),
        const SizedBox(height: 4),
        const Text('Sellers list their Merkato shop (tera), upload trade licence & TIN for the Verified badge, and set tiered wholesale prices.', style: TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 10),
        Row(children: [
          _stat('Orders', '${s.orders.length}'),
          _stat('Sales', etb(revenue)),
          _stat('Products', '${mine.length}'),
        ]),
        const SizedBox(height: 8),
        for (final p in mine) Card(child: ListTile(leading: Text(p.emoji, style: const TextStyle(fontSize: 28)), title: Text(p.name), subtitle: Text('${etb(p.price)} · stock ${p.stock} · MOQ ${p.moq}'))),
        if (mine.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('No products yet')),
      ]),
    );
  }

  Widget _stat(String l, String v) => Expanded(
        child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
          Text(v, style: const TextStyle(fontWeight: FontWeight.bold, color: kGreen), overflow: TextOverflow.ellipsis),
          Text(l, style: const TextStyle(fontSize: 12)),
        ]))),
      );

  void _addProduct(BuildContext context, AppState s) {
    final name = TextEditingController(), price = TextEditingController(), moq = TextEditingController(text: '1'), tera = TextEditingController(text: 'Addis Ketema');
    String cat = MockData.categories.first.id;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
        title: const Text('New product'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Product name')),
          const SizedBox(height: 8),
          TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Unit price (ETB)')),
          const SizedBox(height: 8),
          TextField(controller: moq, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Minimum order qty (1 = retail)')),
          const SizedBox(height: 8),
          TextField(controller: tera, decoration: const InputDecoration(labelText: 'Your tera / location')),
          const SizedBox(height: 8),
          Wrap(spacing: 6, children: [for (final c in MockData.categories) ChoiceChip(label: Text(c.en), selected: cat == c.id, onSelected: (_) => set(() => cat = c.id))]),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final pr = double.tryParse(price.text), m = int.tryParse(moq.text) ?? 1;
              if (name.text.trim().isEmpty || pr == null || pr <= 0) return;
              final emoji = MockData.categories.firstWhere((c) => c.id == cat).emoji;
              s.addProduct(Product(
                id: 'u${DateTime.now().millisecondsSinceEpoch}', name: name.text.trim(), nameAm: name.text.trim(),
                category: cat, seller: kMyShop, tera: tera.text.trim().isEmpty ? 'Addis Ketema' : tera.text.trim(),
                emoji: emoji, description: 'Listed by $kMyShop.', price: pr, moq: m < 1 ? 1 : m,
                wholesale: m > 1, verified: false, rating: 0, tiers: m > 1 ? [PriceTier(m, pr)] : const [],
              ));
              Navigator.pop(ctx);
            },
            child: const Text('Publish'),
          ),
        ],
      )),
    );
  }
}
