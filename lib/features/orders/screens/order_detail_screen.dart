import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/graphql/queries/order_queries.dart';
import '../../../models/order_model.dart';

class OrderDetailScreen extends StatelessWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.currency(symbol: '৳', decimalDigits: 2);
    final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      appBar: AppBar(title: const Text('Order Details')),
      body: Query(
        options: QueryOptions(
          document: gql(OrderQueries.getOrderById),
          variables: {'id': orderId},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
        builder: (result, {fetchMore, refetch}) {
          if (result.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (result.hasException || result.data == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 8),
                  Text(result.exception?.toString() ?? 'Order not found'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => refetch!(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final data = result.data!['orders_by_pk'];
          if (data == null) {
            return const Center(child: Text('Order not found'));
          }

          final order = OrderModel.fromJson(data);

          return RefreshIndicator(
            onRefresh: () async => refetch!(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Order ID & Status ──────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Order #${order.id.substring(0, 8)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _StatusBadge(status: order.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Placed on ${dateFmt.format(order.createdAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Shipping Address ───────────────────────
                _SectionCard(
                  title: 'Shipping Address',
                  icon: Icons.location_on_outlined,
                  child: Text(
                    order.shippingAddress?.toString() ?? 'N/A',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 16),

                // ── Items ──────────────────────────────────
                _SectionCard(
                  title: 'Items (${order.items.length})',
                  icon: Icons.shopping_bag_outlined,
                  child: Column(
                    children: order.items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: item.product != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        item.product!.primaryImage,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : const Icon(Icons.image_outlined),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.product?.name ?? 'Product',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${currency.format(item.unitPrice)} × ${item.quantity}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              currency.format(item.lineTotal),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Price Summary ──────────────────────────
                _SectionCard(
                  title: 'Price Summary',
                  icon: Icons.receipt_outlined,
                  child: Column(
                    children: [
                      _PriceRow(
                        label: 'Total',
                        value: currency.format(order.totalAmount),
                        isBold: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Payment ────────────────────────────────
                _SectionCard(
                  title: 'Payment',
                  icon: Icons.payment_outlined,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: order.paymentStatus == 'paid'
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          (order.paymentStatus ?? 'unpaid').toUpperCase(),
                          style: TextStyle(
                            color: order.paymentStatus == 'paid'
                                ? Colors.green
                                : Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Cancel Button ──────────────────────────
                if (order.status == OrderStatus.pending ||
                    order.status == OrderStatus.confirmed)
                  Mutation(
                    options: MutationOptions(
                      document: gql(OrderMutations.cancelOrder),
                      onCompleted: (data) {
                        if (data != null) refetch!();
                      },
                    ),
                    builder: (runMutation, result) {
                      return OutlinedButton.icon(
                        onPressed: (result?.isLoading ?? false)
                            ? null
                            : () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Cancel Order'),
                                    content: const Text(
                                      'Are you sure you want to cancel this order?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('No'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              theme.colorScheme.error,
                                        ),
                                        child: const Text('Yes, Cancel'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  runMutation({'id': order.id});
                                }
                              },
                        icon: (result?.isLoading ?? false)
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.cancel_outlined),
                        label: const Text('Cancel Order'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                          side: BorderSide(color: theme.colorScheme.error),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _PriceRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isBold ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final OrderStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case OrderStatus.pending:
        color = Colors.orange;
      case OrderStatus.confirmed:
        color = Colors.blue;
      case OrderStatus.processing:
        color = Colors.indigo;
      case OrderStatus.shipped:
        color = Colors.teal;
      case OrderStatus.delivered:
        color = Colors.green;
      case OrderStatus.cancelled:
        color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
