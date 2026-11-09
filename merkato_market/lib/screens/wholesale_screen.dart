import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../state/app_state.dart';
import 'login_screen.dart';
import 'product_screen.dart';
import '../core/api.dart';

/// Alibaba-style B2B tab: MOQ, tiered pricing and Request-for-Quote (RFQ).
class WholesaleScreen extends StatelessWidget {
  const WholesaleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final items = s.products.where((p) => p.wholesale).toList();
    return Scaffold(
      appBar: AppBar(title: Text(s.t('wholesale'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (!s.loggedIn) { await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())); }
          if (s.loggedIn && context.mounted) _rfqDialog(context, s);
        },
        icon: const Icon(Icons.request_quote_outlined),
        label: Text(s.t('rfq')),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 90), children: [
        if (s.rfqs.isNotEmpty) ...[
          const Text('Your quote requests', style: TextStyle(fontWeight: FontWeight.bold)),
          for (final r in s.rfqs)
            Card(child: ListTile(
              dense: true,
              leading: const Icon(Icons.hourglass_top, color: kGreen),
              title: Text('${r.product} × ${r.qty}'),
              subtitle: Text('${r.target != null ? 'Target ${etb(r.target!)} · ' : ''}Awaiting seller offers'),
            )),
          const SizedBox(height: 8),
        ],
        for (final p in items)
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductScreen(p.id))),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Text(p.emoji, style: const TextStyle(fontSize: 44)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.pname(p), style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${p.seller} · ${p.tera}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 4),
                    Text('${etb(p.tiers.isNotEmpty ? p.tiers.last.price : p.price)} – ${etb(p.price)}', style: const TextStyle(color: kGreen, fontWeight: FontWeight.bold)),
                    Text('${s.t('moq')}: ${p.moq}', style: const TextStyle(fontSize: 12)),
                  ])),
                  const Icon(Icons.chevron_right),
                ]),
              ),
            ),
          ),
      ]),
    );
  }

  void _rfqDialog(BuildContext context, AppState s) {
    final prod = TextEditingController(), qty = TextEditingController(), target = TextEditingController(), note = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('rfq')),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: prod, decoration: const InputDecoration(labelText: 'What do you need?')),
          const SizedBox(height: 8),
          TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity')),
          const SizedBox(height: 8),
          TextField(controller: target, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Target unit price (ETB, optional)')),
          const SizedBox(height: 8),
          TextField(controller: note, decoration: const InputDecoration(labelText: 'Notes (delivery date, specs)')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final q = int.tryParse(qty.text);
              if (prod.text.trim().isEmpty || q == null || q <= 0) return;
              final messenger = ScaffoldMessenger.of(context);
              try {
                await s.sendRfq(prod.text.trim(), q, double.tryParse(target.text), note.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text(errText(e))));
              }
            },
            child: const Text('Send to sellers'),
          ),
        ],
      ),
    );
  }
}
