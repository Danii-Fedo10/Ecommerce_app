enum PaymentMethod { telebirr, cbeBirr, chapa, cod }

extension PaymentX on PaymentMethod {
  String get label => switch (this) {
        PaymentMethod.telebirr => 'telebirr',
        PaymentMethod.cbeBirr => 'CBE Birr',
        PaymentMethod.chapa => 'Chapa (cards & banks)',
        PaymentMethod.cod => 'Cash on delivery',
      };
  bool get escrow => this != PaymentMethod.cod;
}

enum OrderStatus { placed, confirmed, out, delivered, completed }

class Category {
  final String id, en, am, emoji;
  const Category(this.id, this.en, this.am, this.emoji);
}

class PriceTier {
  final int minQty;
  final double price;
  const PriceTier(this.minQty, this.price);
}

class Product {
  final String id, name, nameAm, category, seller, tera, emoji, description;
  final double price;
  final double? oldPrice;
  final double rating;
  final int reviews, sold, stock, moq;
  final bool verified, wholesale;
  final List<PriceTier> tiers; // ascending by minQty
  const Product({
    required this.id, required this.name, required this.nameAm, required this.category,
    required this.seller, required this.tera, required this.emoji, required this.description,
    required this.price, this.oldPrice, this.rating = 4.5, this.reviews = 0, this.sold = 0, this.stock = 100,
    this.moq = 1, this.verified = true, this.wholesale = false, this.tiers = const [],
  });
}

class OrderLine {
  final String name;
  final int qty;
  final double unit;
  const OrderLine(this.name, this.qty, this.unit);
}

class Order {
  final String id, address;
  final List<OrderLine> lines;
  final double subtotal, delivery;
  final PaymentMethod payment;
  final DateTime date;
  OrderStatus status;
  Order({required this.id, required this.address, required this.lines, required this.subtotal,
      required this.delivery, required this.payment, required this.date, this.status = OrderStatus.placed});
  double get total => subtotal + delivery;
}

class Rfq {
  final String product, note;
  final int qty;
  final double? target;
  final DateTime date;
  Rfq(this.product, this.qty, this.target, this.note, this.date);
}
