import 'package:flutter_test/flutter_test.dart';
import 'package:merkato_market/data/mock_data.dart';
import 'package:merkato_market/state/app_state.dart';

void main() {
  test('tiered price and MOQ enforcement', () {
    final s = AppState()..products.addAll(MockData.products);
    final gesho = s.byId('p8');
    expect(s.unitPrice(gesho, 10), 260);
    expect(s.unitPrice(gesho, 50), 235);
    s.addToCart(gesho, 1);
    expect(s.cart['p8'], gesho.moq);
  });

  test('cart is grouped by seller', () {
    final s = AppState()..products.addAll([
      MockData.products[7], // sellerId '' in mock data, so group key is ''
    ]);
    s.addToCart(s.byId('p8'), 10);
    expect(s.cartBySeller.length, 1);
    expect(s.subtotal, 2600);
  });
}
