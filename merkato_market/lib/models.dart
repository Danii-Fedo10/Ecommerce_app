// The API stores money as integer santim (1 ETB = 100). The app works in birr,
// so every model converts at the boundary (fromJson here, x100 when sending).
enum PaymentMethod { telebirr, cbeBirr, chapa, cod }

extension PaymentX on PaymentMethod {
  String get label => switch (this) {
        PaymentMethod.telebirr => 'telebirr',
        PaymentMethod.cbeBirr => 'CBE Birr',
        PaymentMethod.chapa => 'Chapa (cards & banks)',
        PaymentMethod.cod => 'Cash on delivery',
      };
  String get api => switch (this) {
        PaymentMethod.telebirr => 'telebirr',
        PaymentMethod.cbeBirr => 'cbe_birr',
        PaymentMethod.chapa => 'chapa',
        PaymentMethod.cod => 'cod',
      };
  bool get escrow => this != PaymentMethod.cod;
}

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
  final String id, sellerId, name, nameAm, category, seller, tera, emoji, description;
  final double price;
  final double? oldPrice;
  final double rating;
  final int reviews, sold, stock, moq;
  final bool verified, wholesale;
  final List<PriceTier> tiers; // ascending by minQty
  const Product({
    required this.id, required this.name, required this.nameAm, required this.category,
    required this.seller, required this.tera, required this.emoji, required this.description,
    required this.price, this.sellerId = '', this.oldPrice, this.rating = 0, this.reviews = 0, this.sold = 0,
    this.stock = 100, this.moq = 1, this.verified = true, this.wholesale = false, this.tiers = const [],
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'] as String,
        sellerId: (j['seller_id'] as String?) ?? '',
        name: j['name'] as String,
        nameAm: (j['name_am'] as String?) ?? (j['name'] as String),
        category: j['category'] as String,
        seller: (j['seller'] as String?) ?? '',
        tera: j['tera'] as String,
        emoji: (j['emoji'] as String?) ?? '🛍️',
        description: (j['description'] as String?) ?? '',
        price: (j['price'] as num) / 100,
        stock: (j['stock'] as num).toInt(),
        moq: (j['moq'] as num).toInt(),
        wholesale: j['wholesale'] == true || j['wholesale'] == 1,
        tiers: [
          for (final t in (j['tiers'] as List? ?? const []))
            PriceTier((t['minQty'] as num).toInt(), (t['price'] as num) / 100),
        ],
      );
}

class OrderLine {
  final String name;
  final int qty;
  final double unit;
  const OrderLine(this.name, this.qty, this.unit);
}

class Order {
  final String id, status, paymentMethod, paymentStatus, address, sellerId;
  final List<OrderLine> lines;
  final double subtotal, delivery, total;
  final DateTime date;
  const Order({
    required this.id, required this.status, required this.paymentMethod, required this.paymentStatus,
    required this.address, required this.sellerId, required this.lines, required this.subtotal,
    required this.delivery, required this.total, required this.date,
  });

  factory Order.fromJson(Map<String, dynamic> j) {
    final a = (j['address'] as Map?) ?? const {};
    return Order(
      id: j['id'] as String,
      status: j['status'] as String,
      paymentMethod: j['payment_method'] as String,
      paymentStatus: j['payment_status'] as String,
      sellerId: (j['seller_id'] as String?) ?? '',
      address: [a['name'], a['phone'], a['subcity'], a['landmark']].where((e) => e != null).join(', '),
      lines: [
        for (final i in (j['items'] as List? ?? const []))
          OrderLine(i['name'] as String, (i['qty'] as num).toInt(), (i['unitPrice'] as num) / 100),
      ],
      subtotal: (j['subtotal'] as num) / 100,
      delivery: (j['delivery_fee'] as num) / 100,
      total: (j['total'] as num) / 100,
      date: DateTime.fromMillisecondsSinceEpoch((j['created_at'] as num).toInt()),
    );
  }

  bool get isCod => paymentMethod == 'cod';
  String get paymentLabel => PaymentMethod.values.firstWhere((m) => m.api == paymentMethod, orElse: () => PaymentMethod.cod).label;
}

class Rfq {
  final String product, note;
  final int qty;
  final double? target;
  final DateTime date;
  const Rfq(this.product, this.qty, this.target, this.note, this.date);

  factory Rfq.fromJson(Map<String, dynamic> j) => Rfq(
        j['product_text'] as String,
        (j['qty'] as num).toInt(),
        j['target_price'] == null ? null : (j['target_price'] as num) / 100,
        (j['note'] as String?) ?? '',
        DateTime.fromMillisecondsSinceEpoch((j['created_at'] as num).toInt()),
      );
}
