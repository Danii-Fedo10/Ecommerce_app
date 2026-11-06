import 'package:flutter/material.dart';
import '../core/strings.dart';
import '../data/mock_data.dart';
import '../models.dart';

/// App-wide state. In production split into repositories (API) + providers
/// (auth, catalog, cart, orders) and persist the cart locally.
class AppState extends ChangeNotifier {
  bool am = false;
  int tab = 0;
  final List<Product> products = List.of(MockData.products);
  final Map<String, int> cart = {};
  final Set<String> wishlist = {};
  final List<Order> orders = [];
  final List<Rfq> rfqs = [];
  PaymentMethod payment = PaymentMethod.telebirr;
  bool express = false;

  String t(String k) => (am ? Strings.am : Strings.en)[k] ?? Strings.en[k] ?? k;
  String pname(Product p) => am ? p.nameAm : p.name;
  void toggleLang() { am = !am; notifyListeners(); }
  void setTab(int i) { tab = i; notifyListeners(); }

  Product byId(String id) => products.firstWhere((p) => p.id == id);
  List<String> get teras => (products.map((p) => p.tera).toSet().toList()..sort());

  /// Tiered (wholesale) pricing: highest tier whose minQty <= qty.
  double unitPrice(Product p, int qty) {
    var price = p.price;
    for (final t in p.tiers) { if (qty >= t.minQty) price = t.price; }
    return price;
  }

  int get cartCount => cart.values.fold(0, (a, b) => a + b);
  double get subtotal => cart.entries.fold(0.0, (a, e) { final p = byId(e.key); return a + unitPrice(p, e.value) * e.value; });
  double get deliveryFee => cart.isEmpty ? 0 : (express ? 150 : 60);
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

  /// Creates the order. TODO(production): call backend -> initiate payment
  /// (telebirr / Chapa) -> hold funds in escrow -> notify seller.
  Order placeOrder(String address) {
    final lines = cart.entries.map((e) { final p = byId(e.key); return OrderLine(p.name, e.value, unitPrice(p, e.value)); }).toList();
    final o = Order(
      id: 'MK-${1001 + orders.length}', address: address, lines: lines,
      subtotal: subtotal, delivery: deliveryFee, payment: payment, date: DateTime.now(),
    );
    orders.insert(0, o);
    cart.clear();
    tab = 3;
    notifyListeners();
    return o;
  }

  /// Demo helper: moves an order forward. In production the seller/courier APIs drive this.
  void advance(Order o) {
    if (o.status.index < OrderStatus.completed.index) {
      o.status = OrderStatus.values[o.status.index + 1];
      notifyListeners();
    }
  }

  void addRfq(Rfq r) { rfqs.insert(0, r); notifyListeners(); }
  void addProduct(Product p) { products.insert(0, p); notifyListeners(); }
}
