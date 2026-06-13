import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/user_model.dart';

class ProfileProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;
  UserModel? _updatedUser;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  UserModel? get updatedUser => _updatedUser;

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
      final payload = <String, dynamic>{};
      if (name != null) payload['name'] = name;
      if (phone != null) payload['phone'] = phone;
      if (avatarUrl != null) payload['avatar_url'] = avatarUrl;

      if (payload.isEmpty) {
        _isLoading = false;
        notifyListeners();
        return true;
      }

      final data = await Supabase.instance.client
          .from('users')
          .update(payload)
          .eq('id', userId)
          .select('id, email, name, phone, avatar_url, role, created_at')
          .single();

      _updatedUser = UserModel.fromJson(data);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to update profile: $e');
      _errorMessage = 'Failed to update profile';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearUpdatedUser() {
    _updatedUser = null;
    notifyListeners();
  }

  void reset() {
    _isLoading = false;
    _errorMessage = null;
    _updatedUser = null;
    notifyListeners();
  }
}
