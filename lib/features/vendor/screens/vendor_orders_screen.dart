import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../features/auth/auth_provider.dart';

class VendorOrdersScreen extends StatefulWidget {
  const VendorOrdersScreen({super.key});

  @override
  State<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends State<VendorOrdersScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrderItems();
  }

  Future<void> _loadOrderItems() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      final vendorId = auth.user?.vendor?.id;
      if (vendorId == null) {
        setState(() {
          _loading = false;
          _error = 'Vendor profile not found';
        });
        return;
      }

      final data = await _supabase
          .from('order_items')
          .select(
            'id, quantity, price_at_purchase, status, order_id, '
            'product:products(id, name, images), '
            'order:orders(id, status, shipping_address, created_at, user:users(name, phone))',
          )
          .eq('vendor_id', vendorId)
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(data as List);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.currency(symbol: '৳', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(title: const Text('Vendor Orders')),
      body: () {
        if (_loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_error != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 8),
                Text('Error: $_error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadOrderItems,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (_items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 64,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                const Text('No orders yet'),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _loadOrderItems,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final item = _items[index];
              final productName = item['product']?['name'] ?? 'Product';
              final status = item['status'] ?? 'pending';
              final qty = item['quantity'] ?? 0;
              final price = (item['price_at_purchase'] ?? 0).toDouble();
              final orderId = (item['order_id'] ?? '') as String;
              final buyerName = item['order']?['user']?['name'] ?? 'Customer';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              productName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _StatusDropdown(
                            currentStatus: status,
                            orderItemId: item['id'] as String,
                            onStatusChanged: _loadOrderItems,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outlined,
                            size: 14,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(buyerName, style: theme.textTheme.bodySmall),
                          const Spacer(),
                          Text(
                            'Qty: $qty × ${currency.format(price)}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Order: #${orderId.length > 8 ? orderId.substring(0, 8) : orderId}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                          Text(
                            currency.format(price * qty),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
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

class _StatusDropdown extends StatefulWidget {
  final String currentStatus;
  final String orderItemId;
  final VoidCallback onStatusChanged;

  const _StatusDropdown({
    required this.currentStatus,
    required this.orderItemId,
    required this.onStatusChanged,
  });

  @override
  State<_StatusDropdown> createState() => _StatusDropdownState();
}

class _StatusDropdownState extends State<_StatusDropdown> {
  final _supabase = Supabase.instance.client;
  bool _loading = false;

  static const _statuses = [
    'pending',
    'confirmed',
    'processing',
    'shipped',
    'delivered',
  ];

  Color _statusColor(String s) {
    switch (s) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'processing':
        return Colors.indigo;
      case 'shipped':
        return Colors.teal;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _loading = true);
    try {
      await _supabase
          .from('order_items')
          .update({'status': newStatus})
          .eq('id', widget.orderItemId);
      widget.onStatusChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _statusColor(widget.currentStatus).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _statusColor(widget.currentStatus).withValues(alpha: 0.3),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: widget.currentStatus,
          isDense: true,
          items: _statuses.map((s) {
            return DropdownMenuItem(
              value: s,
              child: Text(
                s.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _statusColor(s),
                ),
              ),
            );
          }).toList(),
          onChanged: _loading
              ? null
              : (newStatus) {
                  if (newStatus != null && newStatus != widget.currentStatus) {
                    _updateStatus(newStatus);
                  }
                },
        ),
      ),
    );
  }
}
