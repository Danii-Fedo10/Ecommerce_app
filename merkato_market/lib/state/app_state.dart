import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api.dart';
import '../core/strings.dart';
import '../models.dart';

/// App state backed by the Merkato API. Cart, language and wishlist stay on-device;
/// everything else (catalog, orders, quotes, seller tools) comes from the server.
class AppState extends ChangeNotifier {
  final ApiClient api = ApiClient();
  bool am = false;
  int tab = 0;

  // catalog
  final List<Product> products = [];
  bool loading = false;
  String? loadError;

  // local
  final Map<String, int> cart = {};
  final Set<String> wishlist = {};
  PaymentMethod payment = PaymentMethod.telebirr;
  bool express = false;

  // account / server data
  Map<String, dynamic>? user;
  List<Order> orders = [];
  List<Rfq> rfqs = [];
  List<Order> sellerOrders = [];
  List<Order> deliveries = [];
  List<Map<String, dynamic>> pendingSellers = [];
  String? partialError;

  bool get loggedIn => user != null;
  String get role => (user?['role'] as String?) ?? 'buyer';
  String? get sellerStatus => user?['sellerStatus'] as String?;
  String? get userId => user?['id'] as String?;

  String t(String k) => (am ? Strings.am : Strings.en)[k] ?? Strings.en[k] ?? k;
  String pname(Product p) => am ? p.nameAm : p.name;
  void toggleLang() { am = !am; notifyListeners(); }
  void setTab(int i) { tab = i; notifyListeners(); }

  // ---------- startup & auth ----------
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    api.token = prefs.getString('token');
    await loadProducts();
    if (api.token != null) {
      try { await _loadAccount(); } on ApiException catch (e) { if (e.status == 401) await logout(); }
    }
  }

  Future<void> loadProducts() async {
    loading = true; loadError = null; notifyListeners();
    try {
      final r = await api.get('/api/products', {'limit': '50'});
      products..clear()..addAll([for (final j in (r['items'] as List)) Product.fromJson(j as Map<String, dynamic>)]);
    } catch (e) {
      loadError = errText(e);
    }
    loading = false; notifyListeners();
  }

  /// Returns the dev code when the server runs in development (no SMS gateway yet).
  Future<String?> requestOtp(String phone) async {
    final r = await api.post('/api/auth/otp', {'phone': phone});
    return r['devCode'] as String?;
  }

  Future<void> verifyOtp(String phone, String code, String name) async {
    final r = await api.post('/api/auth/verify', {'phone': phone, 'code': code, if (name.trim().isNotEmpty) 'name': name.trim()});
    api.token = r['token'] as String;
    (await SharedPreferences.getInstance()).setString('token', api.token!);
    await _loadAccount();
  }

  Future<void> logout() async {
    api.token = null; user = null; orders = []; rfqs = []; sellerOrders = []; deliveries = []; pendingSellers = [];
    (await SharedPreferences.getInstance()).remove('token');
    notifyListeners();
  }

  Future<void> _loadAccount() async {
    user = Map<String, dynamic>.from(await api.get('/api/me') as Map);
    await Future.wait([loadOrders(), loadRfqs(), _loadRoleData()]);
    notifyListeners();
  }

  Future<void> refreshMe() async {
    user = Map<String, dynamic>.from(await api.get('/api/me') as Map);
    await _loadRoleData();
    notifyListeners();
  }

  Future<void> _loadRoleData() async {
    if (role == 'seller') await loadSellerOrders();
    if (role == 'admin') await loadPendingSellers();
    if (role == 'admin' || role == 'courier') await loadDeliveries();
  }

  // ---------- pricing & cart ----------
  Product byId(String id) => products.firstWhere((p) => p.id == id);

  double unitPrice(Product p, int qty) {
    var price = p.price;
    for (final t in p.tiers) { if (qty >= t.minQty) price = t.price; }
    return price;
  }

  int get cartCount => cart.values.fold(0, (a, b) => a + b);

  /// Cart lines grouped by seller: the API takes one order per seller.
  Map<String, List<MapEntry<Product, int>>> get cartBySeller {
    final out = <String, List<MapEntry<Product, int>>>{};
    for (final e in cart.entries) {
      final p = products.where((x) => x.id == e.key).firstOrNull;
      if (p != null) out.putIfAbsent(p.sellerId, () => []).add(MapEntry(p, e.value));
    }
    return out;
  }

  double get subtotal => cartBySeller.values.expand((l) => l).fold(0.0, (a, e) => a + unitPrice(e.key, e.value) * e.value);
  // Estimate only: must match the server's STANDARD_FEE / EXPRESS_FEE. The server total is authoritative.
  double get deliveryFee => cartBySeller.length * (express ? 150 : 60);
  double get total => subtotal + deliveryFee;

  void addToCart(Product p, int qty) {
    final q = (cart[p.id] ?? 0) + qty;
    cart[p.id] = q < p.moq ? p.moq : q;
    notifyListeners();
  }

  void setQty(Product p, int qty) {
    if (qty <= 0) { cart.remove(p.id); } else { cart[p.id] = qty < p.moq ? p.moq : qty; }
    notifyListeners();
  }

  void toggleWish(String id) { wishlist.contains(id) ? wishlist.remove(id) : wishlist.add(id); notifyListeners(); }
  void setPayment(PaymentMethod m) { payment = m; notifyListeners(); }
  void setExpress(bool v) { express = v; notifyListeners(); }

  // ---------- orders & payment ----------
  /// One order per seller. Successfully ordered items leave the cart even if a later seller fails.
  Future<List<Order>> placeOrders(Map<String, dynamic> address) async {
    final created = <Order>[];
    ApiException? failure;
    partialError = null;
    for (final group in cartBySeller.values.toList()) {
      try {
        final j = await api.post('/api/orders', {
          'items': [for (final e in group) {'productId': e.key.id, 'qty': e.value}],
          'address': address, 'paymentMethod': payment.api, 'express': express,
        });
        created.add(Order.fromJson(Map<String, dynamic>.from(j as Map)));
        for (final e in group) { cart.remove(e.key.id); }
      } on ApiException catch (e) { failure = e; break; }
    }
    if (created.isNotEmpty) { orders.insertAll(0, created); loadProducts(); } // refresh stock
    if (failure != null) {
      if (created.isEmpty) { notifyListeners(); throw failure; }
      partialError = failure.message;
    }
    notifyListeners();
    return created;
  }

  Future<void> loadOrders() async {
    final r = await api.get('/api/orders');
    orders = [for (final j in (r['items'] as List)) Order.fromJson(Map<String, dynamic>.from(j as Map))];
    notifyListeners();
  }

  /// Starts payment. Dev servers (CHAPA_MOCK=1) are paid instantly; otherwise opens Chapa checkout.
  Future<void> payOrder(String orderId) async {
    final r = await api.post('/api/orders/$orderId/pay');
    final url = r['checkoutUrl'] as String;
    if (url.contains('checkout.chapa.co/mock/')) {
      await api.post('/api/dev/orders/$orderId/simulate-payment');
      await loadOrders();
    } else {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); // pull-to-refresh on Orders afterwards
    }
  }

  Future<void> _orderAction(String path, [Map<String, dynamic>? body]) async {
    await api.post(path, body);
    await loadOrders();
  }

  Future<void> cancelOrder(String id) => _orderAction('/api/orders/$id/cancel');
  Future<void> confirmReceipt(String id) => _orderAction('/api/orders/$id/confirm-receipt');
  Future<void> disputeOrder(String id, String reason) => _orderAction('/api/orders/$id/dispute', {'reason': reason});

  // ---------- wholesale quotes ----------
  Future<void> loadRfqs() async {
    final r = await api.get('/api/rfqs');
    rfqs = [for (final j in (r['items'] as List)) Rfq.fromJson(Map<String, dynamic>.from(j as Map))];
    notifyListeners();
  }

  Future<void> sendRfq(String product, int qty, double? target, String note) async {
    await api.post('/api/rfqs', {
      'product': product, 'qty': qty,
      if (target != null) 'targetPrice': (target * 100).round(),
      if (note.isNotEmpty) 'note': note,
    });
    await loadRfqs();
  }

  // ---------- seller ----------
  Future<void> applySeller(String shop, String tera, String tin, String licence) async {
    await api.post('/api/seller/apply', {'shopName': shop, 'tera': tera, 'tin': tin, 'licenseNo': licence});
    await refreshMe();
  }

  Future<void> createProduct({required String name, required String category, required String emoji, required double price, required int stock, required int moq}) async {
    await api.post('/api/seller/products', {
      'name': name, 'category': category, 'emoji': emoji, 'price': (price * 100).round(), 'stock': stock, 'moq': moq,
      if (moq > 1) 'tiers': [{'minQty': moq, 'price': (price * 100).round()}],
    });
    await loadProducts();
  }

  Future<void> loadSellerOrders() async {
    final r = await api.get('/api/seller/orders');
    sellerOrders = [for (final j in (r['items'] as List)) Order.fromJson(Map<String, dynamic>.from(j as Map))];
    notifyListeners();
  }

  Future<void> sellerStep(String id, String step) async { // step: confirm | dispatch
    await api.post('/api/seller/orders/$id/$step');
    await loadSellerOrders();
  }

  // ---------- admin / courier ----------
  Future<void> loadPendingSellers() async {
    final r = await api.get('/api/admin/sellers', {'status': 'pending'});
    pendingSellers = [for (final j in (r['items'] as List)) Map<String, dynamic>.from(j as Map)];
    notifyListeners();
  }

  Future<void> approveSeller(String userId, bool approve) async {
    await api.post('/api/admin/sellers/$userId/verify', {'approve': approve});
    await loadPendingSellers();
  }

  Future<void> loadDeliveries() async {
    final r = await api.get('/api/courier/orders');
    deliveries = [for (final j in (r['items'] as List)) Order.fromJson(Map<String, dynamic>.from(j as Map))];
    notifyListeners();
  }

  Future<void> markDelivered(String id) async {
    await api.post('/api/courier/orders/$id/delivered');
    await loadDeliveries();
  }
}
