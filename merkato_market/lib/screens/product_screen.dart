import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../state/app_state.dart';

class ProductScreen extends StatefulWidget {
  final String id;
  const ProductScreen(this.id, {super.key});
  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  int? qty;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = s.byId(widget.id);
    final q = qty ?? p.moq;
    final unit = s.unitPrice(p, q);

    return Scaffold(
      appBar: AppBar(title: Text(s.pname(p), overflow: TextOverflow.ellipsis)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          height: 200, alignment: Alignment.center,
          decoration: BoxDecoration(color: kGreen.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
          child: Text(p.emoji, style: const TextStyle(fontSize: 96)),
        ),
        const SizedBox(height: 14),
        Text(s.pname(p), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.star, size: 18, color: Colors.amber),
          Text(' ${p.rating} (${p.reviews}) · ${p.sold} ${s.t('sold')}'),
        ]),
        const SizedBox(height: 10),
        Text(etb(unit), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: kGreen)),
        if (p.tiers.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Wholesale pricing', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Card(child: Column(children: [
            for (var i = 0; i < p.tiers.length; i++)
              ListTile(
                dense: true,
                selected: s.unitPrice(p, q) == p.tiers[i].price,
                title: Text(i + 1 < p.tiers.length ? '${p.tiers[i].minQty} – ${p.tiers[i + 1].minQty - 1} units' : '${p.tiers[i].minQty}+ units'),
                trailing: Text(etb(p.tiers[i].price), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
          ])),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Text('${s.t('moq')}: ${p.moq}   '),
          const Spacer(),
          IconButton.outlined(onPressed: q > p.moq ? () => setState(() => qty = q - 1) : null, icon: const Icon(Icons.remove)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('$q', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          IconButton.outlined(onPressed: q < p.stock ? () => setState(() => qty = q + 1) : null, icon: const Icon(Icons.add)),
        ]),
        const Divider(height: 28),
        Card(child: ListTile(
          leading: const CircleAvatar(backgroundColor: kGreen, child: Icon(Icons.store, color: Colors.white)),
          title: Row(children: [Flexible(child: Text(p.seller, overflow: TextOverflow.ellipsis)), if (p.verified) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified, size: 16, color: kGreen))]),
          subtitle: Text('${p.tera}, Merkato${p.verified ? ' · ${s.t('verified')}' : ''}'),
        )),
        const SizedBox(height: 10),
        Text(p.description),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: kYellow.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [const Icon(Icons.shield_outlined, color: kGreen), const SizedBox(width: 10), Expanded(child: Text(s.t('escrow'), style: const TextStyle(fontSize: 12)))]),
        ),
        const SizedBox(height: 90),
      ]),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(top: false, child: Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: () { s.addToCart(p, q); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${s.pname(p)} ×$q'))); },
            child: Text(s.t('add_cart')),
          )),
          const SizedBox(width: 10),
          Expanded(child: FilledButton(
            onPressed: () { s.addToCart(p, q); Navigator.popUntil(context, (r) => r.isFirst); s.setTab(2); },
            child: Text(s.t('buy_now')),
          )),
        ])),
      ),
    );
  }
}
