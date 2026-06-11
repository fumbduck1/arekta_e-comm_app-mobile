import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/admin_app_drawer.dart';
import '../widgets/admin_logout_action.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  String? _error;

  int _userCount = 0;
  int _vendorCount = 0;
  int _orderCount = 0;
  double _totalRevenue = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _supabase.from('users').select('id'),
        _supabase.from('vendors').select('id'),
        _supabase.from('orders').select('total_amount'),
      ]);

      if (!mounted) return;

      final users = results[0] as List;
      final vendors = results[1] as List;
      final orders = (results[2] as List).cast<Map<String, dynamic>>();

      double totalRevenue = 0;
      for (final o in orders) {
        totalRevenue += (o['total_amount'] as num?)?.toDouble() ?? 0;
      }

      setState(() {
        _userCount = users.length;
        _vendorCount = vendors.length;
        _orderCount = orders.length;
        _totalRevenue = totalRevenue;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.currency(symbol: '৳', decimalDigits: 2);

    return Scaffold(
      drawer: const AdminAppDrawer(currentRoute: '/admin/reports'),
      appBar: AppBar(
        title: const Text('Reports'),
        actions: const [AdminLogoutAction()],
      ),
      body: () {
        if (_loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_error != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Error: $_error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadStats,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadStats,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Revenue Card ─────────────────────────
              Card(
                color: theme.colorScheme.primary,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white,
                        size: 36,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currency.format(_totalRevenue),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Total Revenue',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Stat Grid ────────────────────────────
              Row(
                children: [
                  _StatTile(
                    icon: Icons.people,
                    label: 'Users',
                    value: '$_userCount',
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  _StatTile(
                    icon: Icons.store,
                    label: 'Vendors',
                    value: '$_vendorCount',
                    color: Colors.teal,
                  ),
                  const SizedBox(width: 12),
                  _StatTile(
                    icon: Icons.shopping_bag,
                    label: 'Orders',
                    value: '$_orderCount',
                    color: Colors.orange,
                  ),
                ].map((w) => Expanded(child: w)).toList(),
              ),

              const SizedBox(height: 24),

              // ── Averages ─────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Averages',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        label: 'Average Order Value',
                        value: _orderCount > 0
                            ? currency.format(_totalRevenue / _orderCount)
                            : '—',
                      ),
                      const Divider(),
                      _InfoRow(
                        label: 'Orders per User',
                        value: _userCount > 0
                            ? (_orderCount / _userCount).toStringAsFixed(1)
                            : '—',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }(),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
