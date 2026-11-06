import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../data/mock_data.dart';
import '../state/app_state.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String query = '';
  String? cat, tera;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final q = query.toLowerCase();
    final list = s.products.where((p) =>
        (cat == null || p.category == cat) &&
        (tera == null || p.tera == tera) &&
        (q.isEmpty || p.name.toLowerCase().contains(q) || p.nameAm.contains(query) || p.seller.toLowerCase().contains(q) || p.tera.toLowerCase().contains(q))).toList();

    return SafeArea(
      child: CustomScrollView(slivers: [
        SliverAppBar(
          floating: true,
          title: const Text('Merkato Market', style: TextStyle(fontWeight: FontWeight.w800, color: kGreen)),
          actions: [TextButton(onPressed: s.toggleLang, child: Text(s.t('language')))],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => query = v),
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: s.t('search'), isDense: true),
            ),
          ),
        ),
        SliverToBoxAdapter(child: _banner(s)),
        SliverToBoxAdapter(child: _title(s.t('categories'))),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 40,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
              _chip(s.t('all'), cat == null, () => setState(() => cat = null)),
              for (final c in MockData.categories)
                _chip('${c.emoji} ${s.am ? c.am : c.en}', cat == c.id, () => setState(() => cat = cat == c.id ? null : c.id)),
            ]),
          ),
        ),
        SliverToBoxAdapter(child: _title(s.t('teras'))),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 40,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
              for (final t in s.teras) _chip(t, tera == t, () => setState(() => tera = tera == t ? null : t)),
            ]),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverGrid.builder(
            itemCount: list.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.66, crossAxisSpacing: 10, mainAxisSpacing: 10),
            itemBuilder: (_, i) => ProductCard(list[i]),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ]),
    );
  }

  Widget _title(String t) => Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 6), child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)));

  Widget _chip(String label, bool sel, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(label: Text(label), selected: sel, onSelected: (_) => onTap()),
      );

  Widget _banner(AppState s) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: const LinearGradient(colors: [kGreen, Color(0xFF0B6B2B)])),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Merkato, now in your pocket', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          SizedBox(height: 6),
          Text('Retail & wholesale from trusted traders · Pay with telebirr, CBE Birr or cash · Escrow-protected orders',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
      );
}
