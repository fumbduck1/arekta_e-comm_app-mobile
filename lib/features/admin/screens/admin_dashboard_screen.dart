import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/graphql/queries/admin_queries.dart';
import '../widgets/admin_app_drawer.dart';
import '../widgets/admin_logout_action.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  _DashboardPeriod _period = _DashboardPeriod.monthly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final range = _DateRange.current(_period);
    final previousRange = range.previousRange;

    return Scaffold(
      drawer: const AdminAppDrawer(currentRoute: '/admin/dashboard'),
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: const [AdminLogoutAction()],
      ),
      body: Query(
        options: QueryOptions(
          document: gql(AdminQueries.getDashboardInsights),
          variables: {
            'start': range.start.toUtc().toIso8601String(),
            'end': range.end.toUtc().toIso8601String(),
            'previousStart': previousRange.start.toUtc().toIso8601String(),
            'previousEnd': previousRange.end.toUtc().toIso8601String(),
          },
          fetchPolicy: FetchPolicy.networkOnly,
        ),
        builder: (result, {fetchMore, refetch}) {
          if (result.isLoading && result.data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (result.hasException) {
            return Center(child: Text('Error: ${result.exception}'));
          }

          final data = result.data ?? <String, dynamic>{};

          final productsCurrentRows =
              (data['products_current'] as List?) ?? const [];
          final productsPreviousRows =
              (data['products_previous'] as List?) ?? const [];
          final vendorsCurrentRows =
              (data['vendors_current'] as List?) ?? const [];
          final vendorsPreviousRows =
              (data['vendors_previous'] as List?) ?? const [];
          final ordersCurrentRows =
              (data['orders_current'] as List?) ?? const [];
          final ordersPreviousRows =
              (data['orders_previous'] as List?) ?? const [];

          final productCurrent = productsCurrentRows.length;
          final productPrevious = productsPreviousRows.length;
          final vendorCurrent = vendorsCurrentRows.length;
          final vendorPrevious = vendorsPreviousRows.length;
          final orderCurrent = ordersCurrentRows.length;
          final orderPrevious = ordersPreviousRows.length;
          final salesCurrent = _sumOrderTotals(ordersCurrentRows);
          final salesPrevious = _sumOrderTotals(ordersPreviousRows);

          final rankRows = _buildRankRows(data['vendor_order_items'] as List?);

          return RefreshIndicator(
            onRefresh: () async => refetch?.call(),
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
                      onChanged: (value) => setState(() => _period = value),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${_formatRange(range.start)} - ${_formatRange(range.end.subtract(const Duration(seconds: 1)))}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _KpiCard(
                        label: 'Product Uploads',
                        value: '$productCurrent',
                        delta: _buildPercentChange(
                          productCurrent.toDouble(),
                          productPrevious.toDouble(),
                        ),
                        icon: Icons.inventory_2_outlined,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _KpiCard(
                        label: 'Vendor Registrations',
                        value: '$vendorCurrent',
                        delta: _buildPercentChange(
                          vendorCurrent.toDouble(),
                          vendorPrevious.toDouble(),
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
                        value: '$orderCurrent',
                        delta: _buildPercentChange(
                          orderCurrent.toDouble(),
                          orderPrevious.toDouble(),
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
                        ).format(salesCurrent),
                        delta: _buildPercentChange(salesCurrent, salesPrevious),
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
                if (rankRows.isEmpty)
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
                      children: rankRows
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
          );
        },
      ),
    );
  }

  String _formatRange(DateTime value) =>
      DateFormat('dd MMM yyyy').format(value.toLocal());

  double _sumOrderTotals(List rows) {
    double total = 0;
    for (final raw in rows) {
      final row = raw as Map<String, dynamic>;
      total += (row['total_amount'] as num?)?.toDouble() ?? 0;
    }
    return total;
  }

  /// Builds rank rows from raw order items for the selected period.
  List<_VendorRankItem> _buildRankRows(List? rawRows) {
    if (rawRows == null || rawRows.isEmpty) {
      return const <_VendorRankItem>[];
    }

    final Map<String, _RankAccumulator> grouped = {};
    for (final raw in rawRows) {
      final row = raw as Map<String, dynamic>;
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
