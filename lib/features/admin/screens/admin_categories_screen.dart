import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../../core/graphql/queries/admin_queries.dart';
import '../widgets/admin_app_drawer.dart';
import '../widgets/admin_logout_action.dart';

class AdminCategoriesScreen extends StatelessWidget {
  const AdminCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AdminAppDrawer(currentRoute: '/admin/categories'),
      appBar: AppBar(
        title: const Text('Categories'),
        actions: const [AdminLogoutAction()],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context),
        child: const Icon(Icons.add),
      ),
      body: Query(
        options: QueryOptions(
          document: gql(AdminQueries.getCategories),
          fetchPolicy: FetchPolicy.networkOnly,
        ),
        builder: (result, {fetchMore, refetch}) {
          if (result.isLoading && result.data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (result.hasException) {
            return Center(child: Text('Error: ${result.exception}'));
          }

          final categories =
              (result.data?['categories'] as List<dynamic>?) ?? [];
          if (categories.isEmpty) {
            return const Center(child: Text('No categories yet'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index] as Map<String, dynamic>;
              final productCount =
                  (cat['products_aggregate']?['aggregate']?['count'] as int?) ??
                  0;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: cat['image_url'] != null
                      ? CircleAvatar(
                          backgroundImage: NetworkImage(
                            cat['image_url'] as String,
                          ),
                        )
                      : const CircleAvatar(child: Icon(Icons.category)),
                  title: Text(
                    cat['name'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('$productCount products'),
                  trailing: _DeleteCategoryButton(
                    categoryId: cat['id'] as String,
                    onDeleted: () => refetch?.call(),
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
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Category'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'Category name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          Mutation(
            options: MutationOptions(
              document: gql(AdminMutations.createCategory),
              onCompleted: (_) => Navigator.pop(ctx),
            ),
            builder: (runMutation, result) {
              return TextButton(
                onPressed: result?.isLoading == true
                    ? null
                    : () {
                        final name = nameController.text.trim();
                        if (name.isNotEmpty) {
                          runMutation({'name': name, 'slug': _slugify(name)});
                        }
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
    );
  }

  String _slugify(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
  }
}

class _DeleteCategoryButton extends StatelessWidget {
  final String categoryId;
  final VoidCallback onDeleted;

  const _DeleteCategoryButton({
    required this.categoryId,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return Mutation(
      options: MutationOptions(
        document: gql(AdminMutations.deleteCategory),
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
                title: const Text('Delete Category'),
                content: const Text(
                  'This will fail if products are still assigned to this category.',
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
              runMutation({'id': categoryId});
            }
          },
        );
      },
    );
  }
}
