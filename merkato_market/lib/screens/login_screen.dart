import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../state/app_state.dart';

/// Phone-number login. Pops when the user is signed in.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController(), _code = TextEditingController(), _name = TextEditingController();
  bool _codeSent = false, _busy = false;
  String? _error, _hint;

  @override
  void dispose() { _phone.dispose(); _code.dispose(); _name.dispose(); super.dispose(); }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() { _busy = true; _error = null; });
    try { await fn(); } catch (e) { if (mounted) setState(() => _error = errText(e)); }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Icon(Icons.storefront, size: 64, color: kGreen),
        const SizedBox(height: 8),
        const Text('Merkato Market', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Enter your Ethiopian mobile number. We will send a 6-digit code.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 20),
        TextField(
          controller: _phone, enabled: !_codeSent, keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Phone (09… / 07… / +251…)', prefixIcon: Icon(Icons.phone)),
        ),
        if (!_codeSent) ...[
          const SizedBox(height: 12),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Your name (optional, new accounts)')),
        ] else ...[
          const SizedBox(height: 12),
          TextField(controller: _code, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: '6-digit code', prefixIcon: Icon(Icons.lock_outline))),
          if (_hint != null) Text(_hint!, style: const TextStyle(fontSize: 12, color: Colors.orange)),
        ],
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: kRed))),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : () => _run(() async {
            if (!_codeSent) {
              final dev = await s.requestOtp(_phone.text);
              if (!mounted) return;
              setState(() {
                _codeSent = true;
                if (dev != null) { _code.text = dev; _hint = 'Dev server: code filled in automatically (no SMS gateway connected).'; }
              });
            } else {
              await s.verifyOtp(_phone.text, _code.text, _name.text);
              if (context.mounted) Navigator.pop(context);
            }
          }),
          child: _busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_codeSent ? 'Verify & sign in' : 'Send code'),
        ),
        if (_codeSent) TextButton(onPressed: _busy ? null : () => setState(() { _codeSent = false; _code.clear(); _hint = null; }), child: const Text('Change number')),
      ]),
    );
  }
}
