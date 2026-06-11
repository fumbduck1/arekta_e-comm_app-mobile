import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/admin_app_drawer.dart';
import '../widgets/admin_logout_action.dart';

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _categories = [];
  Map<String, int> _productCounts = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _supabase.from('categories').select('id, name, image_url').order('name', ascending: true),
        _supabase.from('products').select('category_id'),
      ]);

      if (!mounted) return;

      final categories = List<Map<String, dynamic>>.from(results[0] as List);
      final allProducts = results[1] as List;
      final productCounts = <String, int>{};
      for (final p in allProducts) {
        final cid = p['category_id'] as String?;
        if (cid != null) {
          productCounts[cid] = (productCounts[cid] ?? 0) + 1;
        }
      }

      setState(() {
        _categories = categories;
        _productCounts = productCounts;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _createCategory(String name, String slug) async {
    try {
      await _supabase.from('categories').insert({'name': name, 'slug': slug});
      await _loadCategories();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create: $e')),
        );
      }
    }
  }

  Future<void> _deleteCategory(String id) async {
    try {
      await _supabase.from('categories').delete().eq('id', id);
      await _loadCategories();
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
      body: () {
        if (_loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_error != null) {
          return Center(child: Text('Error: $_error'));
        }
        if (_categories.isEmpty) {
          return const Center(child: Text('No categories yet'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final cat = _categories[index];
            final productCount = _productCounts[cat['id'] as String] ?? 0;

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
                  onDeleted: _deleteCategory,
                ),
              ),
            );
          },
        );
      }(),
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
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(ctx);
                await _createCategory(name, _slugify(name));
              }
            },
            child: const Text('Create'),
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
  final Future<void> Function(String id) onDeleted;

  const _DeleteCategoryButton({
    required this.categoryId,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
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
          onDeleted(categoryId);
        }
      },
    );
  }
}
