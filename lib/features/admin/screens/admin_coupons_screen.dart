import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/admin_app_drawer.dart';
import '../widgets/admin_logout_action.dart';

class AdminCouponsScreen extends StatefulWidget {
  const AdminCouponsScreen({super.key});

  @override
  State<AdminCouponsScreen> createState() => _AdminCouponsScreenState();
}

class _AdminCouponsScreenState extends State<AdminCouponsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _coupons = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCoupons();
  }

  Future<void> _loadCoupons() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _supabase
          .from('coupons')
          .select('id, code, discount_type, discount_value, min_order, max_uses, used_count, is_active')
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _coupons = List<Map<String, dynamic>>.from(data as List);
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _createCoupon({
    required String code,
    required String discountType,
    required double discountValue,
    double? minOrder,
    int? maxUses,
  }) async {
    try {
      await _supabase.from('coupons').insert({
        'code': code,
        'discount_type': discountType,
        'discount_value': discountValue,
        'min_order': minOrder,
        'max_uses': maxUses,
      });
      await _loadCoupons();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create: $e')),
        );
      }
    }
  }

  Future<void> _toggleActive(String id, bool isActive) async {
    try {
      await _supabase
          .from('coupons')
          .update({'is_active': isActive})
          .eq('id', id);
      await _loadCoupons();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    }
  }

  Future<void> _deleteCoupon(String id) async {
    try {
      await _supabase.from('coupons').delete().eq('id', id);
      await _loadCoupons();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

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
      body: () {
        if (_loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_error != null) {
          return Center(child: Text('Error: $_error'));
        }
        if (_coupons.isEmpty) {
          return const Center(child: Text('No coupons yet'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _coupons.length,
          itemBuilder: (context, index) {
            final c = _coupons[index];
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
                      onToggled: _toggleActive,
                    ),
                    _DeleteCouponButton(
                      couponId: c['id'] as String,
                      onDeleted: _deleteCoupon,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }(),
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
            TextButton(
              onPressed: () async {
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

                Navigator.pop(ctx);
                await _createCoupon(
                  code: code,
                  discountType: discountType,
                  discountValue: value,
                  minOrder: minOrder,
                  maxUses: maxUses,
                );
              },
              child: const Text('Create'),
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
  final Future<void> Function(String id, bool isActive) onToggled;

  const _ToggleCouponButton({
    required this.couponId,
    required this.isActive,
    required this.onToggled,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        isActive ? Icons.toggle_on : Icons.toggle_off,
        color: isActive ? Colors.green : Colors.grey,
        size: 28,
      ),
      tooltip: isActive ? 'Deactivate' : 'Activate',
      onPressed: () => onToggled(couponId, !isActive),
    );
  }
}

class _DeleteCouponButton extends StatelessWidget {
  final String couponId;
  final Future<void> Function(String id) onDeleted;

  const _DeleteCouponButton({required this.couponId, required this.onDeleted});

  @override
  Widget build(BuildContext context) {
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
          onDeleted(couponId);
        }
      },
    );
  }
}
