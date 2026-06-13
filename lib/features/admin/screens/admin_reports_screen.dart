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

  List<Map<String, dynamic>> _ltvData = [];
  List<Map<String, dynamic>> _churnData = [];
  List<Map<String, dynamic>> _categoryTrends = [];

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
        _supabase.from('vw_customer_lifetime_value').select().limit(20),
        _supabase.from('vw_vendor_churn_risk').select().limit(20),
        _supabase.from('vw_category_trends').select().limit(20),
      ]);

      if (!mounted) return;

      final users = results[0] as List;
      final vendors = results[1] as List;
      final orders = (results[2] as List).cast<Map<String, dynamic>>();
      _ltvData = (results[3] as List).cast<Map<String, dynamic>>();
      _churnData = (results[4] as List).cast<Map<String, dynamic>>();
      _categoryTrends = (results[5] as List).cast<Map<String, dynamic>>();

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
      debugPrint('Failed to load reports: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load reports';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.currency(symbol: '\u09F3', decimalDigits: 2);

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
              _buildRevenueCard(theme, currency),
              const SizedBox(height: 16),
              _buildStatGrid(),
              const SizedBox(height: 24),
              _buildAveragesCard(theme, currency),
              const SizedBox(height: 24),
              if (_ltvData.isNotEmpty) _buildLTVSection(theme, currency),
              if (_churnData.isNotEmpty) _buildChurnSection(theme),
              if (_categoryTrends.isNotEmpty)
                _buildCategoryTrendsSection(theme, currency),
            ],
          ),
        );
      }(),
    );
  }

  Widget _buildRevenueCard(ThemeData theme, NumberFormat currency) {
    return Card(
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.account_balance_wallet, color: Colors.white, size: 36),
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
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatGrid() {
    return Row(
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
    );
  }

  Widget _buildAveragesCard(ThemeData theme, NumberFormat currency) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Averages',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _InfoRow(
              label: 'Average Order Value',
              value: _orderCount > 0
                  ? currency.format(_totalRevenue / _orderCount)
                  : '\u2014',
            ),
            const Divider(),
            _InfoRow(
              label: 'Orders per User',
              value: _userCount > 0
                  ? (_orderCount / _userCount).toStringAsFixed(1)
                  : '\u2014',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLTVSection(ThemeData theme, NumberFormat currency) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Customer Lifetime Value',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._ltvData.take(10).map((row) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row['name'] as String? ?? row['email'] as String? ?? 'Unknown',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      currency.format((row['lifetime_value'] as num?)?.toDouble() ?? 0),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _ltvBadgeColor((row['total_orders'] as num?)?.toInt() ?? 0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${row['total_orders']} orders',
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Color _ltvBadgeColor(int orders) {
    if (orders >= 10) return Colors.green;
    if (orders >= 3) return Colors.orange;
    return Colors.grey;
  }

  Widget _buildChurnSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Vendor Churn Risk',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._churnData.take(10).map((row) {
              final risk = row['churn_risk'] as String? ?? 'low';
              final riskColor = risk == 'high'
                  ? Colors.red
                  : risk == 'medium'
                      ? Colors.orange
                      : Colors.green;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row['shop_name'] as String? ?? 'Unknown',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: riskColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        risk.toUpperCase(),
                        style: TextStyle(color: riskColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${row['days_since_last_order'] ?? '\u2014'}d',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTrendsSection(ThemeData theme, NumberFormat currency) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Category Trends',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._categoryTrends.take(10).map((row) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row['category_name'] as String? ?? 'Unknown',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      currency.format((row['revenue'] as num?)?.toDouble() ?? 0),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${row['items_sold']} items',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
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
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
