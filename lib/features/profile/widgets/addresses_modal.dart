import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../address_provider.dart';
import 'address_form.dart';

/// Modal widget for managing user shipping addresses
class AddressesModal extends StatefulWidget {
  final String userId;
  final VoidCallback? onSave;

  const AddressesModal({super.key, required this.userId, this.onSave});

  @override
  State<AddressesModal> createState() => _AddressesModalState();
}

class _AddressesModalState extends State<AddressesModal> {
  @override
  void initState() {
    super.initState();
    // Fetch addresses when modal opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AddressProvider>().fetchAddresses(widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AddressProvider>(
      builder: (context, addressProvider, child) {
        if (addressProvider.isLoading && addressProvider.addresses.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Addresses list
              if (addressProvider.addresses.isEmpty)
                _buildEmptyState(context)
              else
                _buildAddressesList(context, addressProvider),

              // Add address button
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showAddressForm(context, null);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add New Address'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No addresses yet',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add a shipping address to get started',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAddressesList(BuildContext context, AddressProvider provider) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: provider.addresses.map((address) {
        return _AddressCard(
          address: address,
          onEdit: () => _showAddressForm(context, address),
          onDelete: () => _confirmDelete(context, provider, address.id!),
          onSetDefault: () {
            // TODO: Implement set as default
          },
        );
      }).toList(),
    );
  }

  void _showAddressForm(BuildContext context, dynamic address) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddressForm(
        userId: widget.userId,
        address: address,
        onSave: () {
          Navigator.pop(context);
          context.read<AddressProvider>().fetchAddresses(widget.userId);
        },
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    AddressProvider provider,
    String addressId,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Address'),
        content: const Text('Are you sure you want to delete this address?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              navigator.pop();
              final success = await provider.deleteAddress(
                addressId,
                widget.userId,
              );
              if (success && mounted) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Address deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Card widget for displaying an address
class _AddressCard extends StatelessWidget {
  final dynamic address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;

  const _AddressCard({
    required this.address,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with label and default badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    address.label ?? 'Address',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (address.isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Default',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Address details
            Text(address.street, style: const TextStyle(fontSize: 14)),
            Text(
              '${address.city}, ${address.state} ${address.zipCode}',
              style: const TextStyle(fontSize: 14),
            ),
            Text(
              address.country,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 12),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outlined, size: 18),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
