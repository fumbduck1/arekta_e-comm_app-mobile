import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../../core/graphql/queries/admin_queries.dart';
import '../widgets/admin_app_drawer.dart';
import '../widgets/admin_logout_action.dart';

class AdminVendorApprovalsScreen extends StatelessWidget {
  const AdminVendorApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AdminAppDrawer(currentRoute: '/admin/vendors'),
      appBar: AppBar(
        title: const Text('Vendor Approvals'),
        actions: const [AdminLogoutAction()],
      ),
      body: Query(
        options: QueryOptions(
          document: gql(AdminQueries.getVendors),
          fetchPolicy: FetchPolicy.networkOnly,
        ),
        builder: (result, {fetchMore, refetch}) {
          if (result.isLoading && result.data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (result.hasException) {
            return Center(child: Text('Error: ${result.exception}'));
          }

          final vendors = (result.data?['vendors'] as List<dynamic>?) ?? [];
          if (vendors.isEmpty) {
            return const Center(child: Text('No vendors found'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: vendors.length,
            itemBuilder: (context, index) {
              final v = vendors[index] as Map<String, dynamic>;
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
                  trailing: _ApprovalToggle(
                    vendorId: v['id'] as String,
                    isApproved: isApproved,
                    onToggled: () => refetch?.call(),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ApprovalToggle extends StatelessWidget {
  final String vendorId;
  final bool isApproved;
  final VoidCallback onToggled;

  const _ApprovalToggle({
    required this.vendorId,
    required this.isApproved,
    required this.onToggled,
  });

  @override
  Widget build(BuildContext context) {
    return Mutation(
      options: MutationOptions(
        document: gql(AdminMutations.updateVendorApproval),
        onCompleted: (_) => onToggled(),
      ),
      builder: (runMutation, result) {
        return Switch(
          value: isApproved,
          onChanged: (val) {
            runMutation({'id': vendorId, 'isApproved': val});
          },
        );
      },
    );
  }
}
