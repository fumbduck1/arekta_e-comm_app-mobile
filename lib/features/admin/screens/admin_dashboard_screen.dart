import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/admin_app_drawer.dart';
import '../widgets/admin_logout_action.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _supabase = Supabase.instance.client;
  _DashboardPeriod _period = _DashboardPeriod.monthly;
  bool _loading = true;
  String? _error;

  int _productCurrent = 0;
  int _productPrevious = 0;
  int _vendorCurrent = 0;
  int _vendorPrevious = 0;
  int _orderCurrent = 0;
  int _orderPrevious = 0;
  double _salesCurrent = 0;
  double _salesPrevious = 0;
  List<_VendorRankItem> _rankRows = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final range = _DateRange.current(_period);
      final previousRange = range.previousRange;
      final start = range.start.toUtc().toIso8601String();
      final end = range.end.toUtc().toIso8601String();
      final prevStart = previousRange.start.toUtc().toIso8601String();
      final prevEnd = previousRange.end.toUtc().toIso8601String();

      final results = await Future.wait([
        _supabase.from('products').select('id').gte('created_at', start).lt('created_at', end),
        _supabase.from('products').select('id').gte('created_at', prevStart).lt('created_at', prevEnd),
        _supabase.from('vendors').select('id').gte('created_at', start).lt('created_at', end),
        _supabase.from('vendors').select('id').gte('created_at', prevStart).lt('created_at', prevEnd),
        _supabase.from('orders').select('total_amount').gte('created_at', start).lt('created_at', end),
        _supabase.from('orders').select('total_amount').gte('created_at', prevStart).lt('created_at', prevEnd),
        _supabase
            .from('order_items')
            .select('vendor_id, order_id, quantity, price_at_purchase, vendor:vendors(shop_name)')
            .gte('created_at', start)
            .lt('created_at', end),
      ]);

      if (!mounted) return;

      final productsCurrentRows = (results[0] as List);
      final productsPreviousRows = (results[1] as List);
      final vendorsCurrentRows = (results[2] as List);
      final vendorsPreviousRows = (results[3] as List);
      final ordersCurrentRows = (results[4] as List).cast<Map<String, dynamic>>();
      final ordersPreviousRows = (results[5] as List).cast<Map<String, dynamic>>();
      final vendorOrderItems = (results[6] as List).cast<Map<String, dynamic>>();

      setState(() {
        _productCurrent = productsCurrentRows.length;
        _productPrevious = productsPreviousRows.length;
        _vendorCurrent = vendorsCurrentRows.length;
        _vendorPrevious = vendorsPreviousRows.length;
        _orderCurrent = ordersCurrentRows.length;
        _orderPrevious = ordersPreviousRows.length;
        _salesCurrent = _sumOrderTotals(ordersCurrentRows);
        _salesPrevious = _sumOrderTotals(ordersPreviousRows);
        _rankRows = _buildRankRows(vendorOrderItems);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Failed to load dashboard data: $e');
      if (mounted) setState(() { _error = 'Failed to load dashboard data'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        drawer: const AdminAppDrawer(currentRoute: '/admin/dashboard'),
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          actions: const [AdminLogoutAction()],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        drawer: const AdminAppDrawer(currentRoute: '/admin/dashboard'),
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          actions: const [AdminLogoutAction()],
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      drawer: const AdminAppDrawer(currentRoute: '/admin/dashboard'),
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: const [AdminLogoutAction()],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Admin Home',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _PeriodPicker(
                  value: _period,
                  onChanged: (value) {
                    setState(() => _period = value);
                    _loadData();
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${_formatRange(_DateRange.current(_period).start)} - ${_formatRange(_DateRange.current(_period).end.subtract(const Duration(seconds: 1)))}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _KpiCard(
                    label: 'Product Uploads',
                    value: '$_productCurrent',
                    delta: _buildPercentChange(
                      _productCurrent.toDouble(),
                      _productPrevious.toDouble(),
                    ),
                    icon: Icons.inventory_2_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _KpiCard(
                    label: 'Vendor Registrations',
                    value: '$_vendorCurrent',
                    delta: _buildPercentChange(
                      _vendorCurrent.toDouble(),
                      _vendorPrevious.toDouble(),
                    ),
                    icon: Icons.storefront_outlined,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _KpiCard(
                    label: 'Order Frequency',
                    value: '$_orderCurrent',
                    delta: _buildPercentChange(
                      _orderCurrent.toDouble(),
                      _orderPrevious.toDouble(),
                    ),
                    icon: Icons.shopping_bag_outlined,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _KpiCard(
                    label: 'Sales (BDT)',
                    value: NumberFormat.currency(
                      symbol: 'BDT ',
                      decimalDigits: 0,
                    ).format(_salesCurrent),
                    delta: _buildPercentChange(_salesCurrent, _salesPrevious),
                    icon: Icons.currency_exchange_outlined,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Top 20 Vendors (Order Frequency)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (_rankRows.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No vendor order data available for this period.',
                  ),
                ),
              )
            else
              Card(
                child: Column(
                  children: _rankRows
                      .take(20)
                      .toList()
                      .asMap()
                      .entries
                      .map(
                        (entry) => _VendorRankTile(
                          rank: entry.key + 1,
                          item: entry.value,
                        ),
                      )
                      .toList(),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'All newly uploaded vendor products stay pending until super-admin validation from Product Moderation.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  String _formatRange(DateTime value) =>
      DateFormat('dd MMM yyyy').format(value.toLocal());

  double _sumOrderTotals(List<Map<String, dynamic>> rows) {
    double total = 0;
    for (final row in rows) {
      total += (row['total_amount'] as num?)?.toDouble() ?? 0;
    }
    return total;
  }

  List<_VendorRankItem> _buildRankRows(List<Map<String, dynamic>> rawRows) {
    if (rawRows.isEmpty) {
      return const <_VendorRankItem>[];
    }

    final Map<String, _RankAccumulator> grouped = {};
    for (final row in rawRows) {
      final vendorId = row['vendor_id'] as String?;
      if (vendorId == null) continue;

      final vendor = row['vendor'] as Map<String, dynamic>?;
      final orderId = row['order_id'] as String?;
      final quantity = (row['quantity'] as int?) ?? 0;
      final price = (row['price_at_purchase'] as num?)?.toDouble() ?? 0;

      final item = grouped.putIfAbsent(
        vendorId,
        () => _RankAccumulator(
          name: vendor?['shop_name'] as String? ?? 'Unknown Vendor',
        ),
      );

      if (orderId != null) {
        item.orderIds.add(orderId);
      }
      item.sales += quantity * price;
    }

    final items = grouped.entries
        .map(
          (entry) => _VendorRankItem(
            vendorId: entry.key,
            vendorName: entry.value.name,
            orderFrequency: entry.value.orderIds.length,
            sales: entry.value.sales,
          ),
        )
        .toList();

    items.sort((a, b) {
      final byFrequency = b.orderFrequency.compareTo(a.orderFrequency);
      if (byFrequency != 0) return byFrequency;
      return b.sales.compareTo(a.sales);
    });

    return items;
  }

  _PercentChange? _buildPercentChange(double current, double previous) {
    if (previous == 0) {
      if (current == 0) {
        return const _PercentChange(percent: 0, isPositive: true);
      }
      return const _PercentChange(percent: null, isPositive: true);
    }

    final percent = ((current - previous) / previous) * 100;
    return _PercentChange(percent: percent.abs(), isPositive: percent >= 0);
  }
}

enum _DashboardPeriod { monthly, quarterly, yearly }

class _PeriodPicker extends StatelessWidget {
  final _DashboardPeriod value;
  final ValueChanged<_DashboardPeriod> onChanged;

  const _PeriodPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_DashboardPeriod>(
      segments: const [
        ButtonSegment(value: _DashboardPeriod.monthly, label: Text('Month')),
        ButtonSegment(
          value: _DashboardPeriod.quarterly,
          label: Text('Quarter'),
        ),
        ButtonSegment(value: _DashboardPeriod.yearly, label: Text('Year')),
      ],
      selected: {_DashboardPeriod.values[value.index]},
      showSelectedIcon: false,
      onSelectionChanged: (selection) {
        onChanged(selection.first);
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final _PercentChange? delta;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.delta,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final deltaColor = delta == null
        ? Colors.grey
        : (delta!.isPositive ? Colors.green : Colors.red);
    final deltaText = delta == null
        ? 'No prior baseline'
        : delta!.percent == null
        ? 'New vs previous period'
        : '${delta!.isPositive ? '+' : '-'}${delta!.percent!.toStringAsFixed(1)}% vs previous';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Text(
              deltaText,
              style: TextStyle(
                fontSize: 11,
                color: deltaColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VendorRankTile extends StatelessWidget {
  final int rank;
  final _VendorRankItem item;

  const _VendorRankTile({required this.rank, required this.item});

  @override
  Widget build(BuildContext context) {
    final salesFormatter = NumberFormat.currency(
      symbol: 'BDT ',
      decimalDigits: 0,
    );

    return ListTile(
      leading: CircleAvatar(child: Text('$rank')),
      title: Text(
        item.vendorName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text('Orders: ${item.orderFrequency}'),
      trailing: Text(
        salesFormatter.format(item.sales),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _VendorRankItem {
  final String vendorId;
  final String vendorName;
  final int orderFrequency;
  final double sales;

  const _VendorRankItem({
    required this.vendorId,
    required this.vendorName,
    required this.orderFrequency,
    required this.sales,
  });
}

class _RankAccumulator {
  final String name;
  final Set<String> orderIds = {};
  double sales = 0;

  _RankAccumulator({required this.name});
}

class _PercentChange {
  final double? percent;
  final bool isPositive;

  const _PercentChange({required this.percent, required this.isPositive});
}

class _DateRange {
  final DateTime start;
  final DateTime end;

  const _DateRange({required this.start, required this.end});

  static _DateRange current(_DashboardPeriod period) {
    final now = DateTime.now();

    switch (period) {
      case _DashboardPeriod.monthly:
        return _DateRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 1),
        );
      case _DashboardPeriod.quarterly:
        final quarterStartMonth = (((now.month - 1) ~/ 3) * 3) + 1;
        return _DateRange(
          start: DateTime(now.year, quarterStartMonth, 1),
          end: DateTime(now.year, quarterStartMonth + 3, 1),
        );
      case _DashboardPeriod.yearly:
        return _DateRange(
          start: DateTime(now.year, 1, 1),
          end: DateTime(now.year + 1, 1, 1),
        );
    }
  }

  _DateRange get previousRange {
    final monthDelta = end.month - start.month + ((end.year - start.year) * 12);
    return _DateRange(
      start: DateTime(start.year, start.month - monthDelta, start.day),
      end: DateTime(start.year, start.month, start.day),
    );
  }
}
