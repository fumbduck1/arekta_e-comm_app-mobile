import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';

import '../../../core/constants/app_constants.dart';
import '../widgets/admin_app_drawer.dart';
import '../widgets/admin_logout_action.dart';

class AdminCarouselScreen extends StatefulWidget {
  const AdminCarouselScreen({super.key});

  @override
  State<AdminCarouselScreen> createState() => _AdminCarouselScreenState();
}

class _AdminCarouselScreenState extends State<AdminCarouselScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _carousels = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCarousels();
  }

  Future<void> _loadCarousels() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _supabase
          .from('carousels')
          .select('id, image_url, title, sort_order, is_active')
          .order('sort_order', ascending: true);

      if (!mounted) return;
      setState(() {
        _carousels = List<Map<String, dynamic>>.from(data as List);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Failed to load carousels: $e');
      if (mounted) setState(() { _error = 'Failed to load carousels'; _loading = false; });
    }
  }

  Future<void> _toggleActive(String id, bool isActive) async {
    try {
      await _supabase
          .from('carousels')
          .update({'is_active': isActive})
          .eq('id', id);
      await _loadCarousels();
    } catch (e) {
      debugPrint('Failed to update carousel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Failed to update carousel')),
        );
      }
    }
  }

  Future<void> _deleteCarousel(String id) async {
    try {
      await _supabase.from('carousels').delete().eq('id', id);
      await _loadCarousels();
    } catch (e) {
      debugPrint('Failed to delete carousel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Failed to delete carousel')),
        );
      }
    }
  }

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
      body: () {
        if (_loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_error != null) {
          return Center(child: Text('Error: $_error'));
        }
        if (_carousels.isEmpty) {
          return const Center(child: Text('No carousel banners'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _carousels.length,
          itemBuilder: (context, index) {
            final c = _carousels[index];
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
                          onToggled: _toggleActive,
                        ),
                        _DeleteCarouselButton(
                          carouselId: c['id'] as String,
                          onDeleted: _deleteCarousel,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }(),
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
            TextButton(
              onPressed: _isCreating
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
                        setState(() => _isCreating = true);
                        final imageUrl = await _uploadCarouselImage(
                          imageBytes: imageBytes!,
                          fileName:
                              imageName ??
                              'banner_${DateTime.now().millisecondsSinceEpoch}.jpg',
                        );

                        await _supabase.from('carousels').insert({
                          'title': titleController.text.trim().isEmpty
                              ? null
                              : titleController.text.trim(),
                          'image_url': imageUrl,
                          'link_type': linkType,
                          'link_value':
                              linkValueController.text.trim().isEmpty
                              ? null
                              : linkValueController.text.trim(),
                          'sort_order': sortOrder,
                          'is_active': isActive,
                        });

                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        await _loadCarousels();
                      } catch (e) {
                        debugPrint('Upload failed: $e');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Upload failed')),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isCreating = false);
                      }
                    },
              child: _isCreating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Upload'),
            ),
          ],
        ),
      ),
    );
  }

  bool _isCreating = false;

  Future<String> _uploadCarouselImage({
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    if (!_isValidImage(imageBytes)) {
      throw Exception('Invalid image format. Only JPEG, PNG, GIF, and WebP are allowed.');
    }

    final storage = _supabase.storage.from(
      AppConstants.carouselBucket,
    );
    final safeFileName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = 'admin/${DateTime.now().millisecondsSinceEpoch}_$safeFileName';

    await storage.uploadBinary(
      path,
      imageBytes,
      fileOptions: const FileOptions(upsert: false),
    );

    return storage.getPublicUrl(path);
  }

  bool _isValidImage(Uint8List bytes) {
    if (bytes.length < 4) return false;
    return (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) ||
        (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E) ||
        (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) ||
        (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46);
  }
}

class _ToggleActiveButton extends StatelessWidget {
  final String carouselId;
  final bool isActive;
  final Future<void> Function(String id, bool isActive) onToggled;

  const _ToggleActiveButton({
    required this.carouselId,
    required this.isActive,
    required this.onToggled,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        isActive ? Icons.visibility : Icons.visibility_off,
        color: isActive ? Colors.green : Colors.grey,
      ),
      tooltip: isActive ? 'Deactivate' : 'Activate',
      onPressed: () async { await onToggled(carouselId, !isActive); },
    );
  }
}

class _DeleteCarouselButton extends StatelessWidget {
  final String carouselId;
  final Future<void> Function(String id) onDeleted;

  const _DeleteCarouselButton({
    required this.carouselId,
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
          await onDeleted(carouselId);
        }
      },
    );
  }
}
