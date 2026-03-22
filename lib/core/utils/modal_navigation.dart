import 'package:flutter/material.dart';
import '../widgets/animated_bottom_sheet.dart';

/// Modal navigation helper with pre-configured methods for common modals
class ModalNavigation {
  /// Show profile edit modal
  static Future<bool?> showProfileEditModal(
    BuildContext context, {
    required Widget child,
    VoidCallback? onSave,
    String title = "Edit Profile",
  }) {
    return showAnimatedBottomSheet<bool?>(
      context,
      title: title,
      child: child,
      maxHeight: 0.85,
      onClose: onSave,
    );
  }

  /// Show addresses management modal
  static Future<void> showAddressesModal(
    BuildContext context, {
    required Widget child,
    VoidCallback? onSave,
    String title = "Shipping Addresses",
  }) {
    return showAnimatedBottomSheet<void>(
      context,
      title: title,
      child: child,
      maxHeight: 0.9,
      onClose: onSave,
    );
  }

  /// Show product filters modal
  static Future<Map<String, dynamic>?> showProductFiltersModal(
    BuildContext context, {
    required Widget child,
    String title = "Filters",
  }) {
    return showAnimatedBottomSheet<Map<String, dynamic>?>(
      context,
      title: title,
      child: child,
      maxHeight: 0.8,
    );
  }

  /// Show checkout details modal
  static Future<void> showCheckoutDetailsModal(
    BuildContext context, {
    required Widget child,
    String title = "Order Summary",
  }) {
    return showAnimatedBottomSheet<void>(
      context,
      title: title,
      child: child,
      maxHeight: 0.85,
    );
  }

  /// Show generic confirmation modal
  static Future<bool?> showConfirmationModal(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = "Confirm",
    String cancelText = "Cancel",
    Color confirmButtonColor = Colors.blue,
  }) {
    return showAnimatedBottomSheet<bool?>(
      context,
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text(message),
          ),
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                    ),
                    child: Text(
                      cancelText,
                      style: const TextStyle(color: Colors.black),
                    ),
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmButtonColor,
                    ),
                    child: Text(confirmText),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      maxHeight: 0.4,
    );
  }

  /// Show generic form modal
  static Future<T?> showFormModal<T>(
    BuildContext context, {
    required String title,
    required Widget formWidget,
    double maxHeight = 0.85,
  }) {
    return showAnimatedBottomSheet<T?>(
      context,
      title: title,
      child: formWidget,
      maxHeight: maxHeight,
    );
  }

  /// Show loading indicator modal (non-dismissible)
  static void showLoadingModal(
    BuildContext context, {
    String message = "Loading...",
  }) {
    showAnimatedBottomSheet(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Text(message),
          ),
        ],
      ),
      isDismissible: false,
      enableDrag: false,
      maxHeight: 0.25,
    );
  }

  /// Show error modal
  static Future<void> showErrorModal(
    BuildContext context, {
    required String title,
    required String message,
    String closeText = "Close",
  }) {
    return showAnimatedBottomSheet<void>(
      context,
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text(
              message,
              style: const TextStyle(color: Colors.red),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: Text(closeText),
            ),
          ),
        ],
      ),
      maxHeight: 0.4,
    );
  }
}
