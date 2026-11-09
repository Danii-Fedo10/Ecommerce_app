import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../models.dart';
import '../state/app_state.dart';
import 'login_screen.dart';

const _subcities = ['Addis Ketema', 'Arada', 'Bole', 'Gullele', 'Kirkos', 'Kolfe Keranio', 'Lideta', 'Nifas Silk-Lafto', 'Yeka', 'Akaki Kaliti', 'Lemi Kura'];

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _phone = TextEditingController(), _landmark = TextEditingController();
  String _subcity = 'Addis Ketema';
  bool _busy = false;

  @override
  void dispose() { _name.dispose(); _phone.dispose(); _landmark.dispose(); super.dispose(); }


  Future<void> _submit(AppState s) async {
    if (!_form.currentState!.validate()) return;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!s.loggedIn) {
      await nav.push(MaterialPageRoute(builder: (_) => const LoginScreen()));
      if (!s.loggedIn || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      final created = await s.placeOrders({
        'name': _name.text.trim(), 'phone': _phone.text.trim(), 'subcity': _subcity, 'landmark': _landmark.text.trim(),
      });
      nav.popUntil((r) => r.isFirst);
      s.setTab(3);
      messenger.showSnackBar(SnackBar(content: Text(s.partialError == null
          ? (created.length == 1 ? 'Order ${created.first.id} placed' : '${created.length} orders placed')
          : '${created.length} order(s) placed. Others failed: ${s.partialError}')));
      final needsPay = created.where((o) => !o.isCod).toList();
      if (needsPay.length == 1) await s.payOrder(needsPay.first.id); // several unpaid orders: pay each from Orders
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errText(e))));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(s.t('checkout'))),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Delivery address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('Ethiopian addresses rely on landmarks, so describe where to find you. A courier will call before arriving.', style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 10),
          TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Full name'), validator: (v) => (v == null || v.trim().length < 3) ? 'Enter your name' : null),
          const SizedBox(height: 10),
          TextFormField(
            controller: _phone, keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone (09… / 07… / +251…)', prefixIcon: Icon(Icons.phone)),
            validator: (v) => RegExp(r'^(\+251|0)?[79]\d{8}$').hasMatch((v ?? '').replaceAll(' ', '')) ? null : 'Enter a valid Ethiopian mobile number',
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 6, children: [
            for (final c in _subcities) ChoiceChip(label: Text(c), selected: _subcity == c, onSelected: (_) => setState(() => _subcity = c)),
          ]),
          const SizedBox(height: 10),
          TextFormField(
            controller: _landmark, maxLines: 2,
            decoration: const InputDecoration(labelText: 'Woreda, kebele & nearest landmark', hintText: 'e.g. Behind Mercato Anwar Mosque, blue gate'),
            validator: (v) => (v == null || v.trim().length < 6) ? 'Add a landmark so the courier can find you' : null,
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            // TODO(production): geolocator + reverse geocode, store lat/lng with the address.
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('GPS pin: connect the geolocator package'))),
            icon: const Icon(Icons.my_location), label: const Text('Pin my location (GPS)'),
          ),
          const Divider(height: 32),
          const Text('Delivery speed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          SwitchListTile(contentPadding: EdgeInsets.zero, value: s.express, onChanged: s.setExpress, title: const Text('Express (same day)'), subtitle: Text('${etb(150)} vs standard ${etb(60)} (1–2 days)')),
          const Divider(height: 24),
          const Text('Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          for (final m in PaymentMethod.values)
            Card(
              color: s.payment == m ? kGreen.withValues(alpha: 0.08) : null,
              child: ListTile(
                onTap: () => s.setPayment(m),
                leading: Icon(m == PaymentMethod.cod ? Icons.payments_outlined : Icons.account_balance_wallet_outlined),
                title: Text(m.label),
                subtitle: Text(m.escrow ? 'Held in escrow until delivery' : 'Pay the courier on arrival'),
                trailing: Icon(s.payment == m ? Icons.check_circle : Icons.circle_outlined, color: kGreen),
              ),
            ),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(s.t('total'), style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(etb(s.total), style: const TextStyle(fontWeight: FontWeight.bold, color: kGreen, fontSize: 18)),
          ]),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : () => _submit(s),
            child: _busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(s.t('place_order')),
          ),
        ]),
      ),
    );
  }
}
