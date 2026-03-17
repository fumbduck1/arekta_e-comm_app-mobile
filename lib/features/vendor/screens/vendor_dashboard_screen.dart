import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../features/auth/auth_provider.dart';

class VendorDashboardScreen extends StatefulWidget {
  const VendorDashboardScreen({super.key});

  @override
  State<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends State<VendorDashboardScreen> {
  final _supabase = Supabase.instance.client;
  int _productCount = 0;
  int _orderCount = 0;
  List<Map<String, dynamic>> _recentOrders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      final vendorId = auth.user?.vendor?.id;
      if (vendorId == null) {
        setState(() => _loading = false);
        return;
      }

      final results = await Future.wait([
        _supabase.from('products').select('id').eq('vendor_id', vendorId),
        _supabase.from('order_items').select('id').eq('vendor_id', vendorId),
        _supabase
            .from('order_items')
            .select(
              'id, quantity, price_at_purchase, status, order_id, product:products(id, name, images)',
            )
            .eq('vendor_id', vendorId)
            .order('created_at', ascending: false)
            .limit(5),
      ]);

      if (!mounted) return;
      setState(() {
        _productCount = (results[0] as List).length;
        _orderCount = (results[1] as List).length;
        _recentOrders = List<Map<String, dynamic>>.from(results[2] as List);
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.currency(symbol: '৳', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(title: const Text('Vendor Dashboard')),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Quick Stats Row ────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.inventory_2_outlined,
                    label: 'Products',
                    value: _loading ? '--' : '$_productCount',
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.shopping_bag_outlined,
                    label: 'Orders',
                    value: _loading ? '--' : '$_orderCount',
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.star_outlined,
                    label: 'Rating',
                    value: '--',
                    color: Colors.amber,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Menu Grid ───────────────────────────────────
            Text(
              'Manage',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                _MenuCard(
                  icon: Icons.add_box_outlined,
                  title: 'Add Product',
                  subtitle: 'List new item',
                  onTap: () =>
                      Navigator.of(context).pushNamed('/vendor/products/add'),
                ),
                _MenuCard(
                  icon: Icons.inventory_outlined,
                  title: 'My Products',
                  subtitle: 'Manage listings',
                  onTap: () =>
                      Navigator.of(context).pushNamed('/vendor/products'),
                ),
                _MenuCard(
                  icon: Icons.local_shipping_outlined,
                  title: 'Orders',
                  subtitle: 'Manage orders',
                  onTap: () =>
                      Navigator.of(context).pushNamed('/vendor/orders'),
                ),
                _MenuCard(
                  icon: Icons.local_offer_outlined,
                  title: 'Coupons',
                  subtitle: 'Manage discounts',
                  onTap: () =>
                      Navigator.of(context).pushNamed('/vendor/coupons'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Recent Orders ───────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Orders',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/vendor/orders'),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_recentOrders.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 48,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text('No orders yet'),
                      ],
                    ),
                  ),
                ),
              )
            else
              Card(
                child: Column(
                  children: _recentOrders.map<Widget>((item) {
                    final productName = item['product']?['name'] ?? 'Product';
                    final status = item['status'] ?? 'pending';
                    final qty = item['quantity'] ?? 0;
                    final price = (item['price_at_purchase'] ?? 0).toDouble();

                    return ListTile(
                      title: Text(
                        productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('Qty: $qty'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            currency.format(price * qty),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              color: status == 'delivered'
                                  ? Colors.green
                                  : Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 28),
              const SizedBox(height: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
