import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../core/graphql/graphql_service.dart';
import '../../models/user_model.dart';

/// Provider for managing profile-related operations (edit, update, etc.)
class ProfileProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;
  UserModel? _updatedUser;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  UserModel? get updatedUser => _updatedUser;

  /// Update user profile with new data
  Future<bool> updateProfile({
    required String userId,
    String? name,
    String? phone,
    String? avatarUrl,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final mutation = gql('''
        mutation UpdateUserProfile(
          \$id: uuid!
          \$name: String
          \$phone: String
          \$avatarUrl: String
        ) {
          update_users_by_pk(
            pk_columns: { id: \$id }
            _set: {
              name: \$name
              phone: \$phone
              avatar_url: \$avatarUrl
            }
          ) {
            id
            email
            name
            phone
            avatar_url
            role
            created_at
          }
        }
      ''');

      final result = await GraphQLService.instance.client.value.mutate(
        MutationOptions(
          document: mutation,
          variables: {
            'id': userId,
            'name': name,
            'phone': phone,
            'avatarUrl': avatarUrl,
          },
        ),
      );

      if (result.hasException) {
        _errorMessage = result.exception.toString();
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (result.data == null || result.data!.isEmpty) {
        _errorMessage = 'No data returned from server';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final userData =
          result.data!['update_users_by_pk'] as Map<String, dynamic>;
      _updatedUser = UserModel.fromJson(userData);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update profile: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear updated user (after consuming the result)
  void clearUpdatedUser() {
    _updatedUser = null;
    notifyListeners();
  }

  /// Reset provider state
  void reset() {
    _isLoading = false;
    _errorMessage = null;
    _updatedUser = null;
    notifyListeners();
  }
}
