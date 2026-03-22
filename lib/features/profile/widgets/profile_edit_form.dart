import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/user_model.dart';
import '../profile_provider.dart';

/// Form widget for editing user profile.
/// Emits updated user data when successfully saved.
class ProfileEditForm extends StatefulWidget {
  final UserModel user;
  final VoidCallback? onSave;
  final Function(UserModel)? onUserUpdated;

  const ProfileEditForm({
    super.key,
    required this.user,
    this.onSave,
    this.onUserUpdated,
  });

  @override
  State<ProfileEditForm> createState() => _ProfileEditFormState();
}

class _ProfileEditFormState extends State<ProfileEditForm> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final GlobalKey<FormState> _formKey;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name ?? '');
    _phoneController = TextEditingController(text: widget.user.phone ?? '');
    _formKey = GlobalKey<FormState>();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submitForm(BuildContext context) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final profileProvider = context.read<ProfileProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // Show loading
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Saving profile...'),
        duration: Duration(seconds: 1),
      ),
    );

    final success = await profileProvider.updateProfile(
      userId: widget.user.id,
      name: _nameController.text.trim().isEmpty
          ? null
          : _nameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      // Notify parent widget with updated user
      if (profileProvider.updatedUser != null) {
        widget.onUserUpdated?.call(profileProvider.updatedUser!);
      }

      // Show success message
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );

      // Call onSave callback
      widget.onSave?.call();

      // Dismiss modal after short delay
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        navigator.pop();
      }
    } else {
      // Show error message
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            profileProvider.errorMessage ?? 'Failed to update profile',
          ),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (context, profileProvider, child) {
        return Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Name field
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'Enter your full name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name cannot be empty';
                    }
                    if (value.trim().length < 2) {
                      return 'Name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16.0),

                // Phone field
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    hintText: 'Enter your phone number',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      // Basic phone validation: at least 10 digits
                      final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
                      if (digitsOnly.length < 10) {
                        return 'Phone number must be at least 10 digits';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24.0),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: profileProvider.isLoading
                        ? null
                        : () => _submitForm(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: profileProvider.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),

                // Cancel button
                const SizedBox(height: 8.0),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
