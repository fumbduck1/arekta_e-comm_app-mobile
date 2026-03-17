import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_provider.dart';

class VendorOnboardingScreen extends StatefulWidget {
  const VendorOnboardingScreen({super.key});

  @override
  State<VendorOnboardingScreen> createState() => _VendorOnboardingScreenState();
}

class _VendorOnboardingScreenState extends State<VendorOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();
  final _shopDescriptionController = TextEditingController();
  final _logoUrlController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _shopNameController.dispose();
    _shopDescriptionController.dispose();
    _logoUrlController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.createVendorProfile(
      shopName: _shopNameController.text.trim(),
      shopDescription: _shopDescriptionController.text.trim().isEmpty
          ? null
          : _shopDescriptionController.text.trim(),
      logoUrl: _logoUrlController.text.trim().isEmpty
          ? null
          : _logoUrlController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSubmitting = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Vendor profile created! Please wait for admin approval.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate to pending approval screen
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/vendor/profile', (_) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              authProvider.errorMessage ?? 'Failed to create vendor profile',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Up Your Vendor Shop'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ──────────────────────────────────────
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.store_outlined,
                        size: 64,
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Welcome to Arekta Seller',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tell us about your shop',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ── Shop Name ───────────────────────────────────
                TextFormField(
                  controller: _shopNameController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Shop Name',
                    hintText: 'e.g., Awesome Electronics',
                    prefixIcon: Icon(Icons.store_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Shop name is required';
                    }
                    if (value.trim().length < 2) {
                      return 'Shop name must be at least 2 characters';
                    }
                    if (value.trim().length > 100) {
                      return 'Shop name must not exceed 100 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── Shop Description ───────────────────────────
                TextFormField(
                  controller: _shopDescriptionController,
                  maxLines: 4,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Shop Description (Optional)',
                    hintText:
                        'Tell customers about your shop, products, and values...',
                    prefixIcon: Icon(Icons.description_outlined),
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    if (value != null && value.trim().length > 500) {
                      return 'Description must not exceed 500 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── Logo URL ────────────────────────────────────
                TextFormField(
                  controller: _logoUrlController,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Shop Logo URL (Optional)',
                    hintText: 'https://example.com/logo.png',
                    prefixIcon: Icon(Icons.image_outlined),
                  ),
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      // Basic URL validation
                      final uri = Uri.tryParse(value.trim());
                      if (uri == null || !uri.hasAbsolutePath) {
                        return 'Please enter a valid URL';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Upload your logo to a service like Imgur or CloudinaryLink the image URL here.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 32),

                // ── Info Box ────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outlined,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'What happens next?',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '1. Your shop details will be submitted for review.\n'
                        '2. Our team will verify your information.\n'
                        '3. You\'ll receive an email notification once approved.\n'
                        '4. After approval, you can start listing products.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ── Submit Button ───────────────────────────────
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create Vendor Shop'),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Cancel Button ───────────────────────────────
                OutlinedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
