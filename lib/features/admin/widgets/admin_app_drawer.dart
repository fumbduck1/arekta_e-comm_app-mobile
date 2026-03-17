import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_provider.dart';

class AdminAppDrawer extends StatelessWidget {
  final String currentRoute;

  const AdminAppDrawer({super.key, required this.currentRoute});

  static const List<_DrawerItem> _items = [
    _DrawerItem(
      route: '/admin/dashboard',
      icon: Icons.dashboard_outlined,
      label: 'Dashboard',
    ),
    _DrawerItem(
      route: '/admin/vendors',
      icon: Icons.assignment_ind_outlined,
      label: 'Vendor Approvals',
    ),
    _DrawerItem(
      route: '/admin/products/moderation',
      icon: Icons.fact_check_outlined,
      label: 'Product Moderation',
    ),
    _DrawerItem(
      route: '/admin/carousels',
      icon: Icons.image_outlined,
      label: 'Carousel Banners',
    ),
    _DrawerItem(
      route: '/admin/categories',
      icon: Icons.category_outlined,
      label: 'Categories',
    ),
    _DrawerItem(
      route: '/admin/coupons',
      icon: Icons.local_offer_outlined,
      label: 'Coupons',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.12,
                ),
                child: Icon(
                  Icons.admin_panel_settings_outlined,
                  color: theme.colorScheme.primary,
                ),
              ),
              title: const Text(
                'Admin Console',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('Super-admin controls'),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: _items
                    .map(
                      (item) => ListTile(
                        leading: Icon(item.icon),
                        title: Text(item.label),
                        selected: currentRoute == item.route,
                        onTap: () {
                          Navigator.of(context).pop();
                          if (currentRoute == item.route) {
                            return;
                          }
                          Navigator.of(
                            context,
                          ).pushNamedAndRemoveUntil(item.route, (_) => false);
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                Navigator.of(context).pop();
                final auth = context.read<AuthProvider>();
                await auth.signOut();
                if (!context.mounted) return;
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/', (_) => false);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem {
  final String route;
  final IconData icon;
  final String label;

  const _DrawerItem({
    required this.route,
    required this.icon,
    required this.label,
  });
}
