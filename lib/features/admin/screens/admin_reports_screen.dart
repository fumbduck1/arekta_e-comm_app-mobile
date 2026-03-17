import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/graphql/queries/admin_queries.dart';
import '../widgets/admin_app_drawer.dart';
import '../widgets/admin_logout_action.dart';

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

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
      body: Query(
        options: QueryOptions(
          document: gql(AdminQueries.getDashboardStats),
          fetchPolicy: FetchPolicy.networkOnly,
        ),
        builder: (result, {fetchMore, refetch}) {
          if (result.isLoading && result.data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (result.hasException) {
            return Center(child: Text('Error: ${result.exception}'));
          }

          final data = result.data!;
          final userCount =
              data['users_aggregate']?['aggregate']?['count'] as int?;
          final vendorCount =
              data['vendors_aggregate']?['aggregate']?['count'] as int? ?? 0;
          final orderCount =
              data['orders_aggregate']?['aggregate']?['count'] as int? ?? 0;
          final totalRevenue =
              (data['orders_aggregate_revenue']?['aggregate']?['sum']?['total_amount']
                      as num?)
                  ?.toDouble() ??
              0;

          return RefreshIndicator(
            onRefresh: () async => refetch?.call(),
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
                          currency.format(totalRevenue),
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
                      value: userCount?.toString() ?? '—',
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 12),
                    _StatTile(
                      icon: Icons.store,
                      label: 'Vendors',
                      value: '$vendorCount',
                      color: Colors.teal,
                    ),
                    const SizedBox(width: 12),
                    _StatTile(
                      icon: Icons.shopping_bag,
                      label: 'Orders',
                      value: '$orderCount',
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
                          value: orderCount > 0
                              ? currency.format(totalRevenue / orderCount)
                              : '—',
                        ),
                        const Divider(),
                        _InfoRow(
                          label: 'Orders per User',
                          value: (userCount ?? 0) > 0
                              ? (orderCount / userCount!).toStringAsFixed(1)
                              : '—',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
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
