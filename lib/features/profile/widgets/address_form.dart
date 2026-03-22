import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../address_provider.dart';

/// Form for adding or editing an address
class AddressForm extends StatefulWidget {
  final String userId;
  final Address? address;
  final VoidCallback? onSave;

  const AddressForm({
    super.key,
    required this.userId,
    this.address,
    this.onSave,
  });

  @override
  State<AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends State<AddressForm> {
  late final TextEditingController _labelController;
  late final TextEditingController _streetController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _zipCodeController;
  late final TextEditingController _countryController;
  late final GlobalKey<FormState> _formKey;
  late bool _isDefault;

  @override
  void initState() {
    super.initState();
    _formKey = GlobalKey<FormState>();
    _isDefault = widget.address?.isDefault ?? false;

    _labelController = TextEditingController(text: widget.address?.label ?? '');
    _streetController = TextEditingController(
      text: widget.address?.street ?? '',
    );
    _cityController = TextEditingController(text: widget.address?.city ?? '');
    _stateController = TextEditingController(text: widget.address?.state ?? '');
    _zipCodeController = TextEditingController(
      text: widget.address?.zipCode ?? '',
    );
    _countryController = TextEditingController(
      text: widget.address?.country ?? '',
    );
  }

  @override
  void dispose() {
    _labelController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipCodeController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _submitForm(BuildContext context) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final addressProvider = context.read<AddressProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final isEditing = widget.address != null;
    final newAddress = Address(
      id: widget.address?.id,
      userId: widget.userId,
      street: _streetController.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      zipCode: _zipCodeController.text.trim(),
      country: _countryController.text.trim(),
      label: _labelController.text.trim().isEmpty
          ? null
          : _labelController.text.trim(),
      isDefault: _isDefault,
    );

    final success = isEditing
        ? await addressProvider.updateAddress(newAddress)
        : await addressProvider.addAddress(newAddress);

    if (!mounted) return;

    if (success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Address updated successfully!'
                : 'Address added successfully!',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      widget.onSave?.call();
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            addressProvider.errorMessage ?? 'Failed to save address',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AddressProvider>(
      builder: (context, addressProvider, child) {
        return SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Label (optional) - Home, Work, etc.
                TextFormField(
                  controller: _labelController,
                  decoration: InputDecoration(
                    labelText: 'Address Label (e.g., Home, Work)',
                    hintText: 'Enter a label for this address',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    prefixIcon: const Icon(Icons.label_outline),
                  ),
                ),
                const SizedBox(height: 12.0),

                // Street address
                TextFormField(
                  controller: _streetController,
                  decoration: InputDecoration(
                    labelText: 'Street Address *',
                    hintText: 'Enter street address',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    prefixIcon: const Icon(Icons.location_on_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Street address is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12.0),

                // City
                TextFormField(
                  controller: _cityController,
                  decoration: InputDecoration(
                    labelText: 'City *',
                    hintText: 'Enter city',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    prefixIcon: const Icon(Icons.location_city_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'City is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12.0),

                // State/Province
                TextFormField(
                  controller: _stateController,
                  decoration: InputDecoration(
                    labelText: 'State/Province *',
                    hintText: 'Enter state or province',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    prefixIcon: const Icon(Icons.map_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'State/Province is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12.0),

                // Zip/Postal code
                TextFormField(
                  controller: _zipCodeController,
                  decoration: InputDecoration(
                    labelText: 'ZIP/Postal Code *',
                    hintText: 'Enter ZIP or postal code',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    prefixIcon: const Icon(Icons.markunread_mailbox_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'ZIP/Postal code is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12.0),

                // Country
                TextFormField(
                  controller: _countryController,
                  decoration: InputDecoration(
                    labelText: 'Country *',
                    hintText: 'Enter country',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    prefixIcon: const Icon(Icons.public_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Country is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12.0),

                // Default address checkbox
                CheckboxListTile(
                  value: _isDefault,
                  onChanged: (value) {
                    setState(() {
                      _isDefault = value ?? false;
                    });
                  },
                  title: const Text('Set as default address'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 16.0),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: addressProvider.isLoading
                        ? null
                        : () => _submitForm(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: addressProvider.isLoading
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
                        : Text(
                            widget.address != null
                                ? 'Update Address'
                                : 'Add Address',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
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
