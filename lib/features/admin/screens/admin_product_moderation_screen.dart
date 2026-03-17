import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/graphql/queries/admin_queries.dart';
import '../../../features/auth/auth_provider.dart';
import '../widgets/admin_app_drawer.dart';
import '../widgets/admin_logout_action.dart';

class AdminProductModerationScreen extends StatelessWidget {
  const AdminProductModerationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: 'BDT ', decimalDigits: 0);
    final adminId =
        Provider.of<AuthProvider>(context, listen: false).user?.id ?? '';

    return Scaffold(
      drawer: const AdminAppDrawer(currentRoute: '/admin/products/moderation'),
      appBar: AppBar(
        title: const Text('Product Moderation'),
        actions: const [AdminLogoutAction()],
      ),
      body: Query(
        options: QueryOptions(
          document: gql(AdminQueries.getPendingProducts),
          fetchPolicy: FetchPolicy.networkOnly,
        ),
        builder: (result, {fetchMore, refetch}) {
          if (result.isLoading && result.data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (result.hasException) {
            return Center(child: Text('Error: \${result.exception}'));
          }

          final products = (result.data?['products'] as List<dynamic>?) ?? [];
          if (products.isEmpty) {
            return const Center(
              child: Text('No pending products for validation.'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => refetch?.call(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final p = products[index] as Map<String, dynamic>;
                final vendor = p['vendor'] as Map<String, dynamic>?;
                final createdAt = DateTime.tryParse(
                  p['created_at'] as String? ?? '',
                );
                final moderationStatus =
                    p['moderation_status'] as String? ?? 'pending';
                final moderationNotes = p['moderation_notes'] as String?;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                p['name'] as String? ?? 'Untitled Product',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            _ModerationStatusChip(status: moderationStatus),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Vendor: ${vendor?['shop_name'] ?? 'Unknown'}'),
                        Text(
                          'Vendor profile approved: ${((vendor?['is_approved'] as bool?) ?? false) ? 'Yes' : 'No'}',
                        ),
                        Text(
                          'Price: ${currency.format((p['price'] as num?)?.toDouble() ?? 0)}',
                        ),
                        Text('Stock: ${(p['stock'] as int?) ?? 0}'),
                        if (createdAt != null)
                          Text(
                            'Uploaded: ${DateFormat('dd MMM yyyy, hh:mm a').format(createdAt.toLocal())}',
                          ),
                        if (moderationNotes != null &&
                            moderationNotes.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.notes_outlined,
                                  size: 14,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    moderationNotes,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        _ModerationActions(
                          productId: p['id'] as String,
                          adminId: adminId,
                          onModerated: () => refetch?.call(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Colour-coded chip showing the current moderation_status of a product.
class _ModerationStatusChip extends StatelessWidget {
  final String status;
  const _ModerationStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'approved' => ('Approved', Colors.green),
      'rejected' => ('Rejected', Colors.red),
      _ => ('Pending', Colors.orange),
    };
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      backgroundColor: color.withAlpha(30),
      side: BorderSide(color: color.withAlpha(100)),
      labelPadding: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Approve + Reject buttons. Rejection opens a dialog for optional notes.
class _ModerationActions extends StatelessWidget {
  final String productId;
  final String adminId;
  final VoidCallback onModerated;

  const _ModerationActions({
    required this.productId,
    required this.adminId,
    required this.onModerated,
  });

  Future<String?> _promptRejectionNote(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Product'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Optional note for the vendor…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Mutation(
      options: MutationOptions(
        document: gql(AdminMutations.moderateProduct),
        onCompleted: (data) {
          onModerated();
          final status =
              (data?['update_products_by_pk']?['moderation_status']
                  as String?) ??
              '';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                status == 'approved'
                    ? 'Product approved and now live.'
                    : 'Product rejected.',
              ),
              backgroundColor: status == 'approved'
                  ? Colors.green
                  : Colors.red.shade700,
            ),
          );
        },
        onError: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error: \${error?.graphqlErrors.firstOrNull?.message ?? error}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        },
      ),
      builder: (runMutation, result) {
        final isLoading = result?.isLoading == true;
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: isLoading
                  ? null
                  : () async {
                      final note = await _promptRejectionNote(context);
                      if (note == null) return; // user cancelled
                      runMutation({
                        'id': productId,
                        'isActive': false,
                        'moderationStatus': 'rejected',
                        'moderatedBy': adminId,
                        'moderationNotes': note.isEmpty ? null : note,
                      });
                    },
              icon: const Icon(Icons.cancel_outlined, size: 16),
              label: const Text('Reject'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: isLoading
                  ? null
                  : () => runMutation({
                      'id': productId,
                      'isActive': true,
                      'moderationStatus': 'approved',
                      'moderatedBy': adminId,
                      'moderationNotes': null,
                    }),
              icon: isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_outlined),
              label: const Text('Approve & Publish'),
            ),
          ],
        );
      },
    );
  }
}
