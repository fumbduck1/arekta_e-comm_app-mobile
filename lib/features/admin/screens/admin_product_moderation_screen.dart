import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/auth/auth_provider.dart';
import '../widgets/admin_app_drawer.dart';
import '../widgets/admin_logout_action.dart';

class AdminProductModerationScreen extends StatefulWidget {
  const AdminProductModerationScreen({super.key});

  @override
  State<AdminProductModerationScreen> createState() =>
      _AdminProductModerationScreenState();
}

class _AdminProductModerationScreenState
    extends State<AdminProductModerationScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;
  bool _isModerating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _supabase
          .from('products')
          .select(
            'id, name, price, stock, created_at, moderation_status, moderation_notes, vendor:vendors(shop_name, is_approved)',
          )
          .eq('moderation_status', 'pending')
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _products = List<Map<String, dynamic>>.from(data as List);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Failed to load products: $e');
      if (mounted) setState(() { _error = 'Failed to load products'; _loading = false; });
    }
  }

  Future<void> _moderateProduct({
    required String productId,
    required bool isActive,
    required String moderationStatus,
    required String moderatedBy,
    String? moderationNotes,
  }) async {
    if (_isModerating) return;
    _isModerating = true;
    try {
      await _supabase
          .from('products')
          .update({
            'is_active': isActive,
            'moderation_status': moderationStatus,
            'moderated_by': moderatedBy,
            'moderation_notes': moderationNotes,
          })
          .eq('id', productId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            moderationStatus == 'approved'
                ? 'Product approved and now live.'
                : 'Product rejected.',
          ),
          backgroundColor: moderationStatus == 'approved'
              ? Colors.green
              : Colors.red.shade700,
        ),
      );
      await _loadProducts();
    } catch (e) {
      debugPrint('Moderation action failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Moderation action failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _isModerating = false;
    }
  }

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
      body: () {
        if (_loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_error != null) {
          return Center(child: Text('Error: $_error'));
        }
        if (_products.isEmpty) {
          return const Center(
            child: Text('No pending products for validation.'),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadProducts,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _products.length,
            itemBuilder: (context, index) {
              final p = _products[index];
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
                        onModerated: _moderateProduct,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }(),
    );
  }
}

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

class _ModerationActions extends StatelessWidget {
  final String productId;
  final String adminId;
  final Future<void> Function({
    required String productId,
    required bool isActive,
    required String moderationStatus,
    required String moderatedBy,
    String? moderationNotes,
  }) onModerated;

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
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            final note = await _promptRejectionNote(context);
            if (note == null) return;
            await onModerated(
              productId: productId,
              isActive: false,
              moderationStatus: 'rejected',
              moderatedBy: adminId,
              moderationNotes: note.isEmpty ? null : note,
            );
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
          onPressed: () async {
            await onModerated(
              productId: productId,
              isActive: true,
              moderationStatus: 'approved',
              moderatedBy: adminId,
              moderationNotes: null,
            );
          },
          icon: const Icon(Icons.verified_outlined),
          label: const Text('Approve & Publish'),
        ),
      ],
    );
  }
}
