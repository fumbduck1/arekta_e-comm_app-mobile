import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/admin_app_drawer.dart';
import '../widgets/admin_logout_action.dart';

class AdminVendorApprovalsScreen extends StatefulWidget {
  const AdminVendorApprovalsScreen({super.key});

  @override
  State<AdminVendorApprovalsScreen> createState() =>
      _AdminVendorApprovalsScreenState();
}

class _AdminVendorApprovalsScreenState
    extends State<AdminVendorApprovalsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _vendors = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVendors();
  }

  Future<void> _loadVendors() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _supabase
          .from('vendors')
          .select('id, shop_name, logo_url, is_approved, user:users(name, email)')
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _vendors = List<Map<String, dynamic>>.from(data as List);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Failed to load vendors: $e');
      if (mounted) setState(() { _error = 'Failed to load vendors'; _loading = false; });
    }
  }

  Future<void> _toggleApproval(String id, bool isApproved) async {
    try {
      await _supabase
          .from('vendors')
          .update({'is_approved': isApproved})
          .eq('id', id);
      await _loadVendors();
    } catch (e) {
      debugPrint('Failed to update vendor: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update vendor')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AdminAppDrawer(currentRoute: '/admin/vendors'),
      appBar: AppBar(
        title: const Text('Vendor Approvals'),
        actions: const [AdminLogoutAction()],
      ),
      body: () {
        if (_loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_error != null) {
          return Center(child: Text('Error: $_error'));
        }
        if (_vendors.isEmpty) {
          return const Center(child: Text('No vendors found'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _vendors.length,
          itemBuilder: (context, index) {
            final v = _vendors[index];
            final user = v['user'] as Map<String, dynamic>?;
            final isApproved = v['is_approved'] as bool? ?? false;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: v['logo_url'] != null
                      ? NetworkImage(v['logo_url'] as String)
                      : null,
                  child: v['logo_url'] == null
                      ? const Icon(Icons.store)
                      : null,
                ),
                title: Text(
                  v['shop_name'] as String? ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${user?['name'] ?? 'N/A'} • ${user?['email'] ?? ''}',
                ),
                trailing: Switch(
                  value: isApproved,
                  onChanged: (val) => _toggleApproval(v['id'] as String, val),
                ),
              ),
            );
          },
        );
      }(),
    );
  }
}
