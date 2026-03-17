import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_provider.dart';

class VendorPendingApprovalScreen extends StatefulWidget {
  const VendorPendingApprovalScreen({super.key});

  @override
  State<VendorPendingApprovalScreen> createState() =>
      _VendorPendingApprovalScreenState();
}

class _VendorPendingApprovalScreenState
    extends State<VendorPendingApprovalScreen> {
  late TextEditingController _shopNameController;
  late TextEditingController _shopDescriptionController;
  late TextEditingController _logoUrlController;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final vendor = context.read<AuthProvider>().user?.vendor;
    _shopNameController = TextEditingController(text: vendor?.shopName ?? '');
    _shopDescriptionController = TextEditingController(
      text: vendor?.shopDescription ?? '',
    );
    _logoUrlController = TextEditingController(text: vendor?.logoUrl ?? '');
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _shopDescriptionController.dispose();
    _logoUrlController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final shopName = _shopNameController.text.trim();
    if (shopName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Shop name is required.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final auth = context.read<AuthProvider>();
    final success = await auth.updateVendorProfile(
      shopName: shopName,
      shopDescription: _shopDescriptionController.text,
      logoUrl: _logoUrlController.text,
    );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
      if (success) {
        _isEditing = false;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Vendor profile updated!'
              : (auth.errorMessage ?? 'Failed to update vendor profile.'),
        ),
        backgroundColor: success
            ? Colors.green
            : Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.user;
        final vendor = user?.vendor;
        final isApproved = vendor?.isApproved ?? false;

        return Scaffold(
          appBar: AppBar(title: const Text('Vendor Profile'), elevation: 0),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Status Card ─────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: (isApproved ? Colors.green : Colors.amber)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (isApproved ? Colors.green : Colors.amber)
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isApproved
                              ? Icons.verified_outlined
                              : Icons.hourglass_empty_outlined,
                          color: isApproved ? Colors.green[700] : Colors.amber[700],
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isApproved
                                    ? 'Vendor Approved'
                                    : 'Approval Pending',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isApproved
                                      ? Colors.green[700]
                                      : Colors.amber[700],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isApproved
                                    ? 'Your shop is live. You can update details anytime.'
                                    : 'Your vendor application is under review',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isApproved
                                      ? Colors.green[900]
                                      : Colors.amber[900],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Shop Details ────────────────────────────────
                  Text(
                    'Shop Details',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Shop Name
                  _buildDetailField(
                    label: 'Shop Name',
                    icon: Icons.store_outlined,
                    value: vendor?.shopName ?? 'Not set',
                    controller: _shopNameController,
                    isEditable: true,
                  ),
                  const SizedBox(height: 16),

                  // Shop Description
                  _buildDetailField(
                    label: 'Shop Description',
                    icon: Icons.description_outlined,
                    value: vendor?.shopDescription ?? 'Not provided',
                    controller: _shopDescriptionController,
                    isMultiline: true,
                    isEditable: true,
                  ),
                  const SizedBox(height: 16),

                  // Logo URL
                  _buildDetailField(
                    label: 'Shop Logo',
                    icon: Icons.image_outlined,
                    value: vendor?.logoUrl ?? 'Not provided',
                    controller: _logoUrlController,
                    isEditable: true,
                    isUrl: true,
                  ),
                  const SizedBox(height: 32),

                  // ── Application Timeline ────────────────────────
                  Text(
                    'Application Timeline',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTimelineItem(
                    context,
                    step: '1',
                    title: 'Application Submitted',
                    date: vendor?.createdAt != null
                        ? _formatDate(vendor!.createdAt)
                        : 'N/A',
                    isDone: true,
                  ),
                  _buildTimelineConnector(),
                  _buildTimelineItem(
                    context,
                    step: '2',
                    title: 'Under Review',
                    date: isApproved ? 'Completed' : 'In progress',
                    isDone: isApproved,
                  ),
                  _buildTimelineConnector(),
                  _buildTimelineItem(
                    context,
                    step: '3',
                    title: 'Approval Notification',
                    date: isApproved ? 'Approved' : 'Pending',
                    isDone: isApproved,
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
                          'Our team typically reviews vendor applications within 24-48 hours. '
                          'You will receive an email notification once a decision is made. '
                          'In the meantime, you can update your shop details below.',
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

                  // ── Edit / Save Buttons ─────────────────────────
                  if (!_isEditing)
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _isEditing = true),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit Details'),
                    )
                  else ...[
                    ElevatedButton(
                      onPressed: _isSaving ? null : _handleSave,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Save Changes'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => setState(() => _isEditing = false),
                      child: const Text('Cancel'),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // ── Sign Out Button ─────────────────────────────
                  OutlinedButton(
                    onPressed: () => auth.signOut(),
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailField({
    required String label,
    required IconData icon,
    required String value,
    required TextEditingController controller,
    bool isEditable = false,
    bool isMultiline = false,
    bool isUrl = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isEditing && isEditable)
          TextFormField(
            controller: controller,
            maxLines: isMultiline ? 3 : 1,
            decoration: InputDecoration(
              hintText: value,
              border: const OutlineInputBorder(),
            ),
          )
        else
          Container(
            width: double.maxFinite,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.5),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
      ],
    );
  }

  Widget _buildTimelineItem(
    BuildContext context, {
    required String step,
    required String title,
    required String date,
    required bool isDone,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Column(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: isDone
                  ? Colors.green.withValues(alpha: 0.2)
                  : theme.colorScheme.primary.withValues(alpha: 0.1),
              child: Text(
                step,
                style: TextStyle(
                  color: isDone ? Colors.green : theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                date,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineConnector() {
    return Padding(
      padding: const EdgeInsets.only(left: 29, top: 4, bottom: 4),
      child: Container(
        width: 2,
        height: 24,
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
