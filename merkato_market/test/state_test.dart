import 'package:flutter_test/flutter_test.dart';
import 'package:merkato_market/state/app_state.dart';

void main() {
  test('tiered price and MOQ enforcement', () {
    final s = AppState();
    final gesho = s.byId('p8');
    expect(s.unitPrice(gesho, 10), 260);
    expect(s.unitPrice(gesho, 50), 235);
    s.addToCart(gesho, 1);
    expect(s.cart['p8'], gesho.moq);
  });
}
