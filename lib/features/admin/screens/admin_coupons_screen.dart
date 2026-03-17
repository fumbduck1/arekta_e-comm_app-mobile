import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/graphql/queries/admin_queries.dart';
import '../widgets/admin_app_drawer.dart';
import '../widgets/admin_logout_action.dart';

class AdminCouponsScreen extends StatelessWidget {
  const AdminCouponsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '৳', decimalDigits: 0);

    return Scaffold(
      drawer: const AdminAppDrawer(currentRoute: '/admin/coupons'),
      appBar: AppBar(
        title: const Text('Global Coupons'),
        actions: const [AdminLogoutAction()],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context),
        child: const Icon(Icons.add),
      ),
      body: Query(
        options: QueryOptions(
          document: gql(AdminQueries.getCoupons),
          fetchPolicy: FetchPolicy.networkOnly,
        ),
        builder: (result, {fetchMore, refetch}) {
          if (result.isLoading && result.data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (result.hasException) {
            return Center(child: Text('Error: ${result.exception}'));
          }

          final coupons = (result.data?['coupons'] as List<dynamic>?) ?? [];
          if (coupons.isEmpty) {
            return const Center(child: Text('No coupons yet'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: coupons.length,
            itemBuilder: (context, index) {
              final c = coupons[index] as Map<String, dynamic>;
              final isActive = c['is_active'] as bool? ?? true;
              final discountType = c['discount_type'] as String;
              final discountValue =
                  (c['discount_value'] as num?)?.toDouble() ?? 0;
              final usedCount = c['used_count'] as int? ?? 0;
              final maxUses = c['max_uses'] as int?;

              final discountLabel = discountType == 'percentage'
                  ? '${discountValue.toStringAsFixed(0)}%'
                  : currency.format(discountValue);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isActive
                        ? Colors.green[100]
                        : Colors.grey[300],
                    child: Text(
                      discountLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isActive ? Colors.green[800] : Colors.grey,
                      ),
                    ),
                  ),
                  title: Text(
                    c['code'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  subtitle: Text(
                    'Used $usedCount${maxUses != null ? '/$maxUses' : ''}'
                    '${c['min_order'] != null ? ' • Min ${currency.format((c['min_order'] as num).toDouble())}' : ''}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ToggleCouponButton(
                        couponId: c['id'] as String,
                        isActive: isActive,
                        onToggled: () => refetch?.call(),
                      ),
                      _DeleteCouponButton(
                        couponId: c['id'] as String,
                        onDeleted: () => refetch?.call(),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final codeController = TextEditingController();
    final valueController = TextEditingController();
    final minOrderController = TextEditingController();
    final maxUsesController = TextEditingController();
    String discountType = 'percentage';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New Coupon'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: 'Code'),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: discountType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(
                      value: 'percentage',
                      child: Text('Percentage'),
                    ),
                    DropdownMenuItem(value: 'fixed', child: Text('Fixed')),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => discountType = v ?? discountType),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valueController,
                  decoration: InputDecoration(
                    labelText: discountType == 'percentage'
                        ? 'Discount %'
                        : 'Discount ৳',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: minOrderController,
                  decoration: const InputDecoration(
                    labelText: 'Min Order (optional)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: maxUsesController,
                  decoration: const InputDecoration(
                    labelText: 'Max Uses (optional)',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            Mutation(
              options: MutationOptions(
                document: gql(AdminMutations.createCoupon),
                onCompleted: (_) => Navigator.pop(ctx),
              ),
              builder: (runMutation, result) {
                return TextButton(
                  onPressed: result?.isLoading == true
                      ? null
                      : () {
                          final code = codeController.text.trim();
                          final value = double.tryParse(
                            valueController.text.trim(),
                          );
                          if (code.isEmpty || value == null || value <= 0) {
                            return;
                          }
                          final minOrder = double.tryParse(
                            minOrderController.text.trim(),
                          );
                          final maxUses = int.tryParse(
                            maxUsesController.text.trim(),
                          );

                          runMutation({
                            'code': code,
                            'discountType': discountType,
                            'discountValue': value,
                            'minOrder': ?minOrder,
                            'maxUses': ?maxUses,
                          });
                        },
                  child: result?.isLoading == true
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleCouponButton extends StatelessWidget {
  final String couponId;
  final bool isActive;
  final VoidCallback onToggled;

  const _ToggleCouponButton({
    required this.couponId,
    required this.isActive,
    required this.onToggled,
  });

  @override
  Widget build(BuildContext context) {
    return Mutation(
      options: MutationOptions(
        document: gql(AdminMutations.updateCouponStatus),
        onCompleted: (_) => onToggled(),
      ),
      builder: (runMutation, _) {
        return IconButton(
          icon: Icon(
            isActive ? Icons.toggle_on : Icons.toggle_off,
            color: isActive ? Colors.green : Colors.grey,
            size: 28,
          ),
          tooltip: isActive ? 'Deactivate' : 'Activate',
          onPressed: () => runMutation({'id': couponId, 'isActive': !isActive}),
        );
      },
    );
  }
}

class _DeleteCouponButton extends StatelessWidget {
  final String couponId;
  final VoidCallback onDeleted;

  const _DeleteCouponButton({required this.couponId, required this.onDeleted});

  @override
  Widget build(BuildContext context) {
    return Mutation(
      options: MutationOptions(
        document: gql(AdminMutations.deleteCoupon),
        onCompleted: (_) => onDeleted(),
      ),
      builder: (runMutation, _) {
        return IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          tooltip: 'Delete',
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete Coupon'),
                content: const Text(
                  'Are you sure you want to delete this coupon?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              runMutation({'id': couponId});
            }
          },
        );
      },
    );
  }
}
