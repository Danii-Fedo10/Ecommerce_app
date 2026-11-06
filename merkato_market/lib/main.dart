import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'state/app_state.dart';
import 'screens/home_screen.dart';
import 'screens/wholesale_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/account_screen.dart';

void main() => runApp(
      ChangeNotifierProvider(create: (_) => AppState(), child: const MerkatoApp()),
    );

class MerkatoApp extends StatelessWidget {
  const MerkatoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Merkato',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const Shell(),
      );
}

class Shell extends StatelessWidget {
  const Shell({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    const pages = [HomeScreen(), WholesaleScreen(), CartScreen(), OrdersScreen(), AccountScreen()];
    return Scaffold(
      body: IndexedStack(index: s.tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: s.tab,
        onDestinationSelected: s.setTab,
        destinations: [
          NavigationDestination(icon: const Icon(Icons.storefront_outlined), label: s.t('home')),
          NavigationDestination(icon: const Icon(Icons.inventory_2_outlined), label: s.t('wholesale')),
          NavigationDestination(
            icon: Badge(isLabelVisible: s.cartCount > 0, label: Text('${s.cartCount}'), child: const Icon(Icons.shopping_cart_outlined)),
            label: s.t('cart'),
          ),
          NavigationDestination(icon: const Icon(Icons.local_shipping_outlined), label: s.t('orders')),
          NavigationDestination(icon: const Icon(Icons.person_outline), label: s.t('account')),
        ],
      ),
    );
  }
}
