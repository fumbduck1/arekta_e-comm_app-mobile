import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';

import '../../../core/constants/app_constants.dart';
import '../../../core/graphql/queries/admin_queries.dart';
import '../widgets/admin_app_drawer.dart';
import '../widgets/admin_logout_action.dart';

class AdminCarouselScreen extends StatelessWidget {
  const AdminCarouselScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AdminAppDrawer(currentRoute: '/admin/carousels'),
      appBar: AppBar(
        title: const Text('Carousel Banners'),
        actions: const [AdminLogoutAction()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Add Banner'),
      ),
      body: Query(
        options: QueryOptions(
          document: gql(AdminQueries.getCarousels),
          fetchPolicy: FetchPolicy.networkOnly,
        ),
        builder: (result, {fetchMore, refetch}) {
          if (result.isLoading && result.data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (result.hasException) {
            return Center(child: Text('Error: ${result.exception}'));
          }

          final carousels = (result.data?['carousels'] as List<dynamic>?) ?? [];
          if (carousels.isEmpty) {
            return const Center(child: Text('No carousel banners'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: carousels.length,
            itemBuilder: (context, index) {
              final c = carousels[index] as Map<String, dynamic>;
              final isActive = c['is_active'] as bool? ?? true;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: Image.network(
                        c['image_url'] as String? ?? '',
                        height: 140,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          height: 140,
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image, size: 48),
                        ),
                      ),
                    ),
                    ListTile(
                      title: Text(
                        c['title'] as String? ?? 'Untitled',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('Order: ${c['sort_order']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ToggleActiveButton(
                            carouselId: c['id'] as String,
                            isActive: isActive,
                            onToggled: () => refetch?.call(),
                          ),
                          _DeleteCarouselButton(
                            carouselId: c['id'] as String,
                            onDeleted: () => refetch?.call(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final titleController = TextEditingController();
    final linkValueController = TextEditingController();
    final sortOrderController = TextEditingController(text: '0');
    final picker = ImagePicker();
    String? linkType;
    Uint8List? imageBytes;
    String? imageName;
    bool isActive = true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add Carousel Banner'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: linkType,
                  decoration: const InputDecoration(labelText: 'Link Type'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('None')),
                    DropdownMenuItem(value: 'product', child: Text('Product')),
                    DropdownMenuItem(
                      value: 'category',
                      child: Text('Category'),
                    ),
                    DropdownMenuItem(value: 'url', child: Text('URL')),
                  ],
                  onChanged: (value) => setDialogState(() => linkType = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: linkValueController,
                  decoration: const InputDecoration(
                    labelText: 'Link Value',
                    hintText: 'Optional product id, category id, or URL',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sortOrderController,
                  decoration: const InputDecoration(labelText: 'Sort Order'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: isActive,
                  onChanged: (value) => setDialogState(() => isActive = value),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final file = await picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 85,
                    );
                    if (file == null) return;

                    final bytes = await file.readAsBytes();
                    if (!dialogContext.mounted) return;

                    setDialogState(() {
                      imageBytes = bytes;
                      imageName = file.name;
                    });
                  },
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(
                    imageName == null ? 'Pick Banner Image' : imageName!,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            Mutation(
              options: MutationOptions(
                document: gql(AdminMutations.createCarousel),
                onCompleted: (_) => Navigator.pop(dialogContext),
              ),
              builder: (runMutation, result) {
                return TextButton(
                  onPressed: result?.isLoading == true
                      ? null
                      : () async {
                          final sortOrder = int.tryParse(
                            sortOrderController.text.trim(),
                          );
                          if (imageBytes == null || sortOrder == null) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Select an image and enter a valid sort order.',
                                  ),
                                ),
                              );
                            }
                            return;
                          }

                          try {
                            final imageUrl = await _uploadCarouselImage(
                              imageBytes: imageBytes!,
                              fileName:
                                  imageName ??
                                  'banner_${DateTime.now().millisecondsSinceEpoch}.jpg',
                            );

                            runMutation({
                              'title': titleController.text.trim().isEmpty
                                  ? null
                                  : titleController.text.trim(),
                              'imageUrl': imageUrl,
                              'linkType': linkType,
                              'linkValue':
                                  linkValueController.text.trim().isEmpty
                                  ? null
                                  : linkValueController.text.trim(),
                              'sortOrder': sortOrder,
                              'isActive': isActive,
                            });
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Upload failed: $e')),
                              );
                            }
                          }
                        },
                  child: result?.isLoading == true
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Upload'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _uploadCarouselImage({
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    final storage = Supabase.instance.client.storage.from(
      AppConstants.carouselBucket,
    );
    final safeFileName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = 'admin/${DateTime.now().millisecondsSinceEpoch}_$safeFileName';

    await storage.uploadBinary(
      path,
      imageBytes,
      fileOptions: const FileOptions(upsert: true),
    );

    return storage.getPublicUrl(path);
  }
}

class _ToggleActiveButton extends StatelessWidget {
  final String carouselId;
  final bool isActive;
  final VoidCallback onToggled;

  const _ToggleActiveButton({
    required this.carouselId,
    required this.isActive,
    required this.onToggled,
  });

  @override
  Widget build(BuildContext context) {
    return Mutation(
      options: MutationOptions(
        document: gql(AdminMutations.updateCarouselStatus),
        onCompleted: (_) => onToggled(),
      ),
      builder: (runMutation, _) {
        return IconButton(
          icon: Icon(
            isActive ? Icons.visibility : Icons.visibility_off,
            color: isActive ? Colors.green : Colors.grey,
          ),
          tooltip: isActive ? 'Deactivate' : 'Activate',
          onPressed: () =>
              runMutation({'id': carouselId, 'isActive': !isActive}),
        );
      },
    );
  }
}

class _DeleteCarouselButton extends StatelessWidget {
  final String carouselId;
  final VoidCallback onDeleted;

  const _DeleteCarouselButton({
    required this.carouselId,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return Mutation(
      options: MutationOptions(
        document: gql(AdminMutations.deleteCarousel),
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
                title: const Text('Delete Banner'),
                content: const Text(
                  'Are you sure you want to delete this banner?',
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
              runMutation({'id': carouselId});
            }
          },
        );
      },
    );
  }
}
