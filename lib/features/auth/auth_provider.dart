import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/enums.dart';
import '../../models/user_model.dart';

/// Authentication state
enum AuthState { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  AuthState _authState = AuthState.initial;
  UserModel? _user;
  String? _errorMessage;

  AuthState get authState => _authState;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _authState == AuthState.authenticated;
  bool get isLoading => _authState == AuthState.loading;
  String? get vendorId => _user?.vendor?.id;

  /// Initialize — check if there's an existing session
  Future<void> initialize() async {
    final session = _supabase.auth.currentSession;
    if (session != null) {
      await _fetchUserProfile();
    } else {
      _authState = AuthState.unauthenticated;
      notifyListeners();
    }

    // Listen for auth state changes
    _supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        _fetchUserProfile();
      } else if (event == AuthChangeEvent.signedOut) {
        _user = null;
        _authState = AuthState.unauthenticated;
        notifyListeners();
      }
    });
  }

  /// Sign up with email & password
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    UserRole role = UserRole.client,
  }) async {
    try {
      _setLoading();

      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'name': name, 'role': role.apiRole},
      );

      if (response.user != null) {
        await _fetchUserProfile();
        return true;
      }

      _setError('Sign up failed. Please check your email for confirmation.');
      return false;
    } on AuthException catch (e) {
      debugPrint('Sign up error: ${e.message}');
      _setError('Sign up failed. Please try again.');
      return false;
    } catch (e) {
      debugPrint('Sign up error: $e');
      _setError('An unexpected error occurred');
      return false;
    }
  }

  /// Sign in with email & password
  Future<bool> signIn({required String email, required String password}) async {
    try {
      _setLoading();

      await _supabase.auth.signInWithPassword(email: email, password: password);

      await _fetchUserProfile();
      return true;
    } on AuthException catch (e) {
      debugPrint('Sign in error: ${e.message}');
      _setError('Sign in failed. Please check your credentials.');
      return false;
    } catch (e) {
      debugPrint('Sign in error: $e');
      _setError('An unexpected error occurred');
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
    _user = null;
    _authState = AuthState.unauthenticated;
    notifyListeners();
  }

  /// Reset password
  Future<bool> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      return true;
    } on AuthException catch (e) {
      debugPrint('Reset password error: ${e.message}');
      _setError('Failed to send reset email. Please try again.');
      return false;
    }
  }

  /// Debug: Print JWT token payload (only in debug mode)
  void debugPrintJWT() {
    assert(() {
      final session = _supabase.auth.currentSession;
      if (session != null) {
        final token = session.accessToken;
        final parts = token.split('.');
        if (parts.length == 3) {
          String payload = parts[1];
          payload = payload.padRight(
            payload.length + (4 - payload.length % 4) % 4,
            '=',
          );
          try {
            final decoded = utf8.decode(base64.decode(payload));
            debugPrint('========== JWT PAYLOAD DEBUG ==========');
            debugPrint('Raw JWT Payload: $decoded');
            final json = jsonDecode(decoded);
            debugPrint('Parsed JSON: $json');
            debugPrint('Role field: ${json['role']}');
            debugPrint('App Metadata: ${json['app_metadata']}');
            debugPrint('User Metadata: ${json['user_metadata']}');
            debugPrint('==========================================');
          } catch (e) {
            debugPrint('Error decoding JWT: $e');
          }
        }
      } else {
        debugPrint('No active session');
      }
      return true;
    }());
  }

  Future<void> _fetchUserProfile() async {
    try {
      _user = null;
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _authState = AuthState.unauthenticated;
        notifyListeners();
        return;
      }

      final databaseUser = await _fetchUserProfileFromDatabase(userId);
      if (databaseUser != null) {
        _user = databaseUser;
      } else {
        _user = _buildFallbackUserFromSession();
        debugPrint('[AuthProvider] No profile row returned for user $userId');
      }

      _authState = AuthState.authenticated;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      _authState = AuthState.error;
      _errorMessage = 'Failed to fetch user profile';
      _user = null;
      notifyListeners();
    }
  }

  UserModel? _buildFallbackUserFromSession() {
    final sessionUser = _supabase.auth.currentUser;
    if (sessionUser == null) return null;

    final appMetadata = sessionUser.appMetadata;

    final roleStr = appMetadata['role'] as String?;
    final role = roleStr != null
        ? UserRole.fromString(roleStr)
        : UserRole.client;
    final createdAtValue = sessionUser.createdAt;

    DateTime createdAt;
    if (createdAtValue.isEmpty) {
      createdAt = DateTime.now();
    } else {
      createdAt = DateTime.tryParse(createdAtValue) ?? DateTime.now();
    }

    switch (role) {
      case UserRole.vendor:
        return VendorUser(
          id: sessionUser.id,
          email: sessionUser.email ?? '',
          name: sessionUser.userMetadata?['name'] as String?,
          phone: sessionUser.userMetadata?['phone'] as String?,
          avatarUrl: sessionUser.userMetadata?['avatar_url'] as String?,
          createdAt: createdAt,
        );
      case UserRole.superAdmin:
        return AdminUser(
          id: sessionUser.id,
          email: sessionUser.email ?? '',
          name: sessionUser.userMetadata?['name'] as String?,
          phone: sessionUser.userMetadata?['phone'] as String?,
          avatarUrl: sessionUser.userMetadata?['avatar_url'] as String?,
          createdAt: createdAt,
        );
      case UserRole.client:
        return ClientUser(
          id: sessionUser.id,
          email: sessionUser.email ?? '',
          name: sessionUser.userMetadata?['name'] as String?,
          phone: sessionUser.userMetadata?['phone'] as String?,
          avatarUrl: sessionUser.userMetadata?['avatar_url'] as String?,
          createdAt: createdAt,
        );
    }
  }

  /// Refresh user profile
  Future<void> refreshProfile() async {
    await _fetchUserProfile();
  }

  /// Resolve the current vendor profile id for vendor-owned mutations.
  /// If the profile has just been created, a refresh may be needed first.
  Future<String?> ensureVendorId() async {
    if (vendorId != null) return vendorId;

    await _fetchUserProfile();
    return vendorId;
  }

  /// Create vendor profile
  /// Must be called after user is authenticated with vendor role
  Future<bool> createVendorProfile({
    required String shopName,
    String? shopDescription,
    String? logoUrl,
  }) async {
    try {
      if (_user?.id == null) {
        _errorMessage = 'User not authenticated';
        notifyListeners();
        return false;
      }

      final payload = {
        'user_id': _user!.id,
        'shop_name': shopName.trim(),
        'description': _normalizeNullableText(shopDescription),
        'logo_url': _normalizeNullableText(logoUrl),
      };

      final existingVendor = await _supabase
          .from('vendors')
          .select('id')
          .eq('user_id', _user!.id)
          .maybeSingle();

      if (existingVendor == null) {
        await _supabase.from('vendors').insert(payload);
      } else {
        return updateVendorProfile(
          shopName: shopName,
          shopDescription: shopDescription,
          logoUrl: logoUrl,
        );
      }

      await _fetchUserProfile();
      _errorMessage = null;
      notifyListeners();
      return true;
    } on PostgrestException catch (e) {
      debugPrint('Error creating vendor profile: ${e.message}');
      _errorMessage = 'An unexpected error occurred';
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Error creating vendor profile: $e');
      _errorMessage = 'An unexpected error occurred';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateVendorProfile({
    required String shopName,
    String? shopDescription,
    String? logoUrl,
  }) async {
    try {
      final userId = _user?.id;
      if (userId == null) {
        _errorMessage = 'User not authenticated';
        notifyListeners();
        return false;
      }

      // Check if user already has a vendor profile using existing data
      if (_user?.vendor == null) {
        return createVendorProfile(
          shopName: shopName,
          shopDescription: shopDescription,
          logoUrl: logoUrl,
        );
      }

      final updated = await _supabase
          .from('vendors')
          .update({
            'shop_name': shopName.trim(),
            'description': _normalizeNullableText(shopDescription),
            'logo_url': _normalizeNullableText(logoUrl),
          })
          .eq('user_id', userId)
          .select('id')
          .maybeSingle();

      if (updated == null) {
        _errorMessage =
            'Profile update was blocked. Please confirm the vendors UPDATE policy is enabled in Supabase.';
        notifyListeners();
        return false;
      }

      await _fetchUserProfile();
      _errorMessage = null;
      notifyListeners();
      return true;
    } on PostgrestException catch (e) {
      debugPrint('Error updating vendor profile: ${e.message}');
      _errorMessage = 'An unexpected error occurred';
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Error updating vendor profile: $e');
      _errorMessage = 'An unexpected error occurred';
      notifyListeners();
      return false;
    }
  }

  Future<UserModel?> _fetchUserProfileFromDatabase(String userId) async {
    final userData = await _supabase
        .from('users')
        .select('id, email, name, phone, role, avatar_url, created_at')
        .eq('id', userId)
        .maybeSingle();

    if (userData == null) return null;

    final normalized = Map<String, dynamic>.from(userData);
    final vendorData = await _supabase
        .from('vendors')
        .select('id, shop_name, description, logo_url, is_approved, created_at')
        .eq('user_id', userId)
        .maybeSingle();

    if (vendorData != null) {
      normalized['vendor'] = Map<String, dynamic>.from(vendorData);
    }

    return UserModel.fromJson(normalized);
  }

  String? _normalizeNullableText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  void _setLoading() {
    _user = null;
    _authState = AuthState.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _authState = AuthState.error;
    _errorMessage = message;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    if (_authState == AuthState.error) {
      _authState = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  /// Update user profile from profile provider changes
  void updateUserFromProfile(UserModel updatedUser) {
    _user = updatedUser;
    notifyListeners();
  }
}
