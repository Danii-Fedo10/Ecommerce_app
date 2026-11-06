import '../models.dart';

// Sample data only. Replace with a REST/GraphQL repository (see README).
class MockData {
  static const categories = [
    Category('coffee', 'Coffee & Spices', 'ቡና እና ቅመም', '☕'),
    Category('fashion', 'Traditional Wear', 'ባህላዊ ልብስ', '👗'),
    Category('electronics', 'Electronics', 'ኤሌክትሮኒክስ', '📱'),
    Category('home', 'Home & Kitchen', 'የቤት እቃ', '🏠'),
    Category('building', 'Building Materials', 'የግንባታ እቃ', '🧱'),
    Category('auto', 'Auto Parts', 'የመኪና እቃ', '🔧'),
    Category('grain', 'Grains & Food', 'እህል', '🌾'),
  ];

  static const products = <Product>[
    Product(id: 'p1', name: 'Yirgacheffe Coffee 1kg', nameAm: 'ይርጋጨፌ ቡና 1ኪግ', category: 'coffee', seller: 'Abeba Coffee Traders', tera: 'Addis Ketema', emoji: '☕', price: 1200, rating: 4.8, reviews: 214, sold: 1800, description: 'Washed, single-origin roasted beans. Sealed 1kg pack.'),
    Product(id: 'p2', name: 'Berbere Spice Mix 500g', nameAm: 'በርበሬ 500ግ', category: 'coffee', seller: 'Selam Spices', tera: 'Addis Ketema', emoji: '🌶️', price: 350, rating: 4.6, reviews: 98, sold: 900, description: 'Freshly ground traditional berbere.'),
    Product(id: 'p3', name: 'Habesha Kemis (Hand-woven)', nameAm: 'ሀበሻ ቀሚስ', category: 'fashion', seller: 'Tigist Shema', tera: 'Shema Tera', emoji: '👗', price: 4500, oldPrice: 5200, rating: 4.7, reviews: 63, sold: 210, description: 'Cotton shemma with tilet embroidery. Sizes S–XL.'),
    Product(id: 'p4', name: 'Men Traditional Suit', nameAm: 'የወንድ ባህላዊ ልብስ', category: 'fashion', seller: 'Tigist Shema', tera: 'Shema Tera', emoji: '🧥', price: 3800, rating: 4.4, reviews: 31, sold: 120, description: 'Cotton set, ideal for holidays and weddings.'),
    Product(id: 'p5', name: 'Android Smartphone 6.5"', nameAm: 'ስማርት ስልክ', category: 'electronics', seller: 'Tana Electronics', tera: 'Tana Gebeya', emoji: '📱', price: 14500, oldPrice: 16000, rating: 4.3, reviews: 77, sold: 340, stock: 40, description: '128GB, dual SIM, 12-month warranty.'),
    Product(id: 'p6', name: 'Power Bank 20,000mAh', nameAm: 'ፓወር ባንክ', category: 'electronics', seller: 'Tana Electronics', tera: 'Tana Gebeya', emoji: '🔋', price: 1800, rating: 4.5, reviews: 120, sold: 760, description: 'Fast charge, dual USB.'),
    Product(id: 'p7', name: 'Injera Mitad (Electric)', nameAm: 'የኤሌክትሪክ ምጣድ', category: 'home', seller: 'Bete Home Goods', tera: 'Addis Ketema', emoji: '🍳', price: 5200, rating: 4.6, reviews: 45, sold: 190, description: '50cm non-stick electric mitad.'),
    Product(id: 'p8', name: 'Gesho (Hops) Leaves 1kg', nameAm: 'ጌሾ 1ኪግ', category: 'grain', seller: 'Gesho Tera Wholesale', tera: 'Gesho Tera', emoji: '🌿', price: 260, rating: 4.2, reviews: 22, sold: 500, moq: 10, wholesale: true, tiers: [PriceTier(10, 260), PriceTier(50, 235), PriceTier(200, 210)], description: 'Dried gesho for tej and tella. Sold by the kilo, wholesale.'),
    Product(id: 'p9', name: 'Teff (Magna) 100kg Sack', nameAm: 'ጤፍ 100ኪግ', category: 'grain', seller: 'Merkato Grain Union', tera: 'Addis Ketema', emoji: '🌾', price: 14500, rating: 4.7, reviews: 56, sold: 320, moq: 2, wholesale: true, tiers: [PriceTier(2, 14500), PriceTier(10, 14100), PriceTier(30, 13700)], description: 'Cleaned white teff, bulk sacks.'),
    Product(id: 'p10', name: 'Corrugated Iron Sheet (G28)', nameAm: 'ቆርቆሮ', category: 'building', seller: 'Che\'d Tera Metals', tera: 'Che\'d Tera', emoji: '🧱', price: 780, rating: 4.3, reviews: 40, sold: 1500, moq: 20, wholesale: true, tiers: [PriceTier(20, 780), PriceTier(100, 745), PriceTier(500, 710)], description: '3m sheets, bundle delivery by truck.'),
    Product(id: 'p11', name: 'Brake Pad Set (Toyota)', nameAm: 'የፍሬን ሸራ', category: 'auto', seller: 'Bomb Tera Auto', tera: 'Bomb Tera', emoji: '🔧', price: 2300, rating: 4.4, reviews: 28, sold: 210, moq: 5, wholesale: true, tiers: [PriceTier(5, 2300), PriceTier(20, 2150)], description: 'OEM-grade, fits Corolla/Vitz.'),
    Product(id: 'p12', name: 'Cooking Oil 20L', nameAm: 'የምግብ ዘይት 20ሊ', category: 'grain', seller: 'Merkato Grain Union', tera: 'Addis Ketema', emoji: '🛢️', price: 3900, rating: 4.1, reviews: 33, sold: 640, moq: 5, wholesale: true, tiers: [PriceTier(5, 3900), PriceTier(25, 3750), PriceTier(100, 3600)], description: 'Refined sunflower oil jerrycan.'),
  ];
}
