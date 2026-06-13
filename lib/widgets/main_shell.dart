import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;
import '../features/auth/auth_provider.dart';
import '../features/cart/cart_provider.dart';

/// Shell widget that hosts bottom navigation and switches between top-level tabs
class MainShell extends StatefulWidget {
  final int currentIndex;
  final Widget child;

  const MainShell({super.key, required this.currentIndex, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _safeIndex(int index, int length) {
    if (length <= 0) return 0;
    if (index < 0) return 0;
    if (index >= length) return length - 1;
    return index;
  }

  // Client navigation items
  static const _clientNavItems = [
    BottomNavigationBarItem(
      icon: Icon(Icons.home_outlined),
      activeIcon: Icon(Icons.home),
      label: 'Home',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.grid_view_outlined),
      activeIcon: Icon(Icons.grid_view),
      label: 'Products',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.shopping_cart_outlined),
      activeIcon: Icon(Icons.shopping_cart),
      label: 'Cart',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.receipt_long_outlined),
      activeIcon: Icon(Icons.receipt_long),
      label: 'Orders',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person_outlined),
      activeIcon: Icon(Icons.person),
      label: 'Profile',
    ),
  ];

  // Vendor navigation items
  static const _vendorNavItems = [
    BottomNavigationBarItem(
      icon: Icon(Icons.dashboard_outlined),
      activeIcon: Icon(Icons.dashboard),
      label: 'Dashboard',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.inventory_2_outlined),
      activeIcon: Icon(Icons.inventory_2),
      label: 'Products',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.receipt_long_outlined),
      activeIcon: Icon(Icons.receipt_long),
      label: 'Orders',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person_outlined),
      activeIcon: Icon(Icons.person),
      label: 'Profile',
    ),
  ];

  static const _clientRoutes = ['/', '/products', '/cart', '/orders', '/profile'];
  static const _vendorRoutes = [
    '/vendor/dashboard',
    '/vendor/products',
    '/vendor/orders',
    '/vendor/profile',
  ];

  void _onClientTap(int index) {
    final safe = _safeIndex(index, _clientRoutes.length);
    if (safe == widget.currentIndex) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(_clientRoutes[safe], (route) => false);
  }

  void _onVendorTap(int index) {
    final safe = _safeIndex(index, _vendorRoutes.length);
    if (safe == widget.currentIndex) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(_vendorRoutes[safe], (route) => false);
  }

  // void _onAdminTap(int index) {
  //   if (index == widget.currentIndex) return;
  //   switch (index) {
  //     case 0:
  //       Navigator.of(context).pushNamed('/admin/dashboard');
  //     case 1:
  //       Navigator.of(context).pushNamed('/admin/vendors');
  //     case 2:
  //       Navigator.of(context).pushNamed('/admin/carousels');
  //     case 3:
  //       Navigator.of(context).pushNamed('/admin/categories');
  //     case 4:
  //       Navigator.of(context).pushNamed('/admin/coupons');
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, CartProvider>(
      builder: (context, auth, cart, _) {
        final user = auth.user;
        final isAdmin = user?.isAdmin ?? false;
        final isVendor = user?.isVendor ?? false;

        // Build navigation based on role
        if (isAdmin) {
          return Scaffold(body: widget.child);
        } else if (isVendor) {
          return Scaffold(
            body: widget.child,
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _safeIndex(
                widget.currentIndex,
                _vendorNavItems.length,
              ),
              onTap: _onVendorTap,
              type: BottomNavigationBarType.fixed,
              items: _vendorNavItems,
            ),
          );
        } else {
          // Client navigation
          return Scaffold(
            body: widget.child,
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _safeIndex(
                widget.currentIndex,
                _clientNavItems.length,
              ),
              onTap: _onClientTap,
              type: BottomNavigationBarType.fixed,
              items: [
                _clientNavItems[0],
                _clientNavItems[1],
                // Cart tab with badge
                BottomNavigationBarItem(
                  icon: badges.Badge(
                    showBadge: cart.itemCount > 0,
                    badgeContent: Text(
                      '${cart.itemCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                    child: const Icon(Icons.shopping_cart_outlined),
                  ),
                  activeIcon: badges.Badge(
                    showBadge: cart.itemCount > 0,
                    badgeContent: Text(
                      '${cart.itemCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                    child: const Icon(Icons.shopping_cart),
                  ),
                  label: 'Cart',
                ),
                _clientNavItems[3],
                _clientNavItems[4],
              ],
            ),
          );
        }
      },
    );
  }
}
