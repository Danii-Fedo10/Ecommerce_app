import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../data/mock_data.dart';
import '../state/app_state.dart';
import 'login_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _run(BuildContext context, Future<void> Function() fn) async {
    final messenger = ScaffoldMessenger.of(context);
    try { await fn(); } catch (e) { messenger.showSnackBar(SnackBar(content: Text(errText(e)))); }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(s.t('account'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (!s.loggedIn) ...[
          const ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(radius: 28, child: Icon(Icons.person)), title: Text('Guest'), subtitle: Text('Sign in with your phone number')),
          FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())), child: const Text('Sign in')),
        ] else ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(radius: 28, child: Icon(Icons.person)),
            title: Text((s.user?['name'] as String?) ?? (s.user?['phone'] as String)),
            subtitle: Text('${s.user?['phone']} · ${s.role}'),
            trailing: TextButton(onPressed: s.logout, child: const Text('Sign out')),
          ),
        ],
        SwitchListTile(contentPadding: EdgeInsets.zero, value: s.am, onChanged: (_) => s.toggleLang(), title: const Text('አማርኛ / Amharic')),
        ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.favorite_border), title: const Text('Wishlist'), trailing: Text('${s.wishlist.length}')),
        if (s.loggedIn && s.role == 'buyer') _applyCard(context, s),
        if (s.role == 'seller') ..._seller(context, s),
        if (s.role == 'admin') ..._admin(context, s),
        if (s.role == 'admin' || s.role == 'courier') ..._deliveries(context, s),
      ]),
    );
  }

  Widget _applyCard(BuildContext context, AppState s) => Card(
        child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Sell on Merkato', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('Apply with your shop, TIN and trade licence. Once verified you can list retail and wholesale products.', style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 8),
          FilledButton(onPressed: () => _applyDialog(context, s), child: const Text('Apply as seller')),
        ])),
      );

  void _applyDialog(BuildContext context, AppState s) {
    final shop = TextEditingController(), tera = TextEditingController(), tin = TextEditingController(), lic = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seller application'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: shop, decoration: const InputDecoration(labelText: 'Shop name')),
          const SizedBox(height: 8),
          TextField(controller: tera, decoration: const InputDecoration(labelText: 'Tera / location (e.g. Shema Tera)')),
          const SizedBox(height: 8),
          TextField(controller: tin, decoration: const InputDecoration(labelText: 'TIN')),
          const SizedBox(height: 8),
          TextField(controller: lic, decoration: const InputDecoration(labelText: 'Trade licence number')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await s.applySeller(shop.text, tera.text, tin.text, lic.text);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) { messenger.showSnackBar(SnackBar(content: Text(errText(e)))); }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  List<Widget> _seller(BuildContext context, AppState s) {
    final verified = s.sellerStatus == 'verified';
    final mine = s.products.where((p) => p.sellerId == s.userId).toList();
    return [
      const Divider(height: 30),
      Row(children: [
        const Text('Seller dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const Spacer(),
        FilledButton.icon(onPressed: verified ? () => _addProduct(context, s) : null, icon: const Icon(Icons.add), label: const Text('Add product')),
      ]),
      if (!verified) Padding(padding: const EdgeInsets.only(top: 8), child: Text(s.sellerStatus == 'rejected' ? 'Your application was rejected.' : 'Verification pending. An admin is checking your TIN and licence.', style: const TextStyle(color: Colors.orange))),
      const SizedBox(height: 8),
      Row(children: [_stat('Orders', '${s.sellerOrders.length}'), _stat('Products', '${mine.length}')]),
      for (final p in mine) Card(child: ListTile(leading: Text(p.emoji, style: const TextStyle(fontSize: 28)), title: Text(p.name), subtitle: Text('${etb(p.price)} · stock ${p.stock} · MOQ ${p.moq}'))),
      const SizedBox(height: 8),
      const Text('Incoming orders', style: TextStyle(fontWeight: FontWeight.bold)),
      if (s.sellerOrders.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('No orders yet')),
      for (final o in s.sellerOrders)
        Card(child: ListTile(
          title: Text('${o.id} · ${etb(o.total)}'),
          subtitle: Text('${o.lines.map((l) => '${l.name} ×${l.qty}').join(', ')}\n${o.status} · ${o.paymentLabel}'),
          isThreeLine: true,
          trailing: o.status == 'placed'
              ? FilledButton(onPressed: () => _run(context, () => s.sellerStep(o.id, 'confirm')), child: const Text('Confirm'))
              : o.status == 'confirmed'
                  ? FilledButton(onPressed: () => _run(context, () => s.sellerStep(o.id, 'dispatch')), child: const Text('Dispatch'))
                  : null,
        )),
    ];
  }

  List<Widget> _admin(BuildContext context, AppState s) => [
        const Divider(height: 30),
        const Text('Admin: seller applications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        if (s.pendingSellers.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('No pending applications')),
        for (final a in s.pendingSellers)
          Card(child: ListTile(
            title: Text('${a['shop_name']} · ${a['tera']}'),
            subtitle: Text('${a['phone']}\nTIN ${a['tin']} · Licence ${a['license_no']}'),
            isThreeLine: true,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.close, color: kRed), onPressed: () => _run(context, () => s.approveSeller(a['user_id'] as String, false))),
              IconButton(icon: const Icon(Icons.check_circle, color: kGreen), onPressed: () => _run(context, () => s.approveSeller(a['user_id'] as String, true))),
            ]),
          )),
      ];

  List<Widget> _deliveries(BuildContext context, AppState s) => [
        const Divider(height: 30),
        Row(children: [
          const Text('Deliveries in progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Spacer(),
          IconButton(onPressed: () => _run(context, s.loadDeliveries), icon: const Icon(Icons.refresh)),
        ]),
        if (s.deliveries.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Nothing out for delivery')),
        for (final o in s.deliveries)
          Card(child: ListTile(
            title: Text('${o.id} · ${etb(o.total)}${o.isCod ? ' (collect cash)' : ''}'),
            subtitle: Text(o.address),
            trailing: FilledButton(onPressed: () => _run(context, () => s.markDelivered(o.id)), child: const Text('Delivered')),
          )),
      ];

  Widget _stat(String l, String v) => Expanded(
        child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
          Text(v, style: const TextStyle(fontWeight: FontWeight.bold, color: kGreen)),
          Text(l, style: const TextStyle(fontSize: 12)),
        ]))),
      );

  void _addProduct(BuildContext context, AppState s) {
    final name = TextEditingController(), price = TextEditingController(), stock = TextEditingController(text: '10'), moq = TextEditingController(text: '1');
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
          TextField(controller: stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock')),
          const SizedBox(height: 8),
          TextField(controller: moq, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Minimum order qty (1 = retail)')),
          const SizedBox(height: 8),
          Wrap(spacing: 6, children: [for (final c in MockData.categories) ChoiceChip(label: Text(c.en), selected: cat == c.id, onSelected: (_) => set(() => cat = c.id))]),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final pr = double.tryParse(price.text), st = int.tryParse(stock.text), m = int.tryParse(moq.text) ?? 1;
              if (name.text.trim().isEmpty || pr == null || pr <= 0 || st == null || st < 0 || m < 1) return;
              final messenger = ScaffoldMessenger.of(context);
              try {
                await s.createProduct(name: name.text.trim(), category: cat, emoji: MockData.categories.firstWhere((c) => c.id == cat).emoji, price: pr, stock: st, moq: m);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) { messenger.showSnackBar(SnackBar(content: Text(errText(e)))); }
            },
            child: const Text('Publish'),
          ),
        ],
      )),
    );
  }
}
