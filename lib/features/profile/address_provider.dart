import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Address {
  final String? id;
  final String userId;
  final String street;
  final String city;
  final String state;
  final String zipCode;
  final String country;
  final String? label;
  final bool isDefault;
  final DateTime? createdAt;

  const Address({
    this.id,
    required this.userId,
    required this.street,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.country,
    this.label,
    this.isDefault = false,
    this.createdAt,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id'] as String?,
      userId: json['user_id'] as String? ?? '',
      street: json['street'] as String? ?? '',
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      zipCode: json['zip_code'] as String? ?? '',
      country: json['country'] as String? ?? '',
      label: json['label'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'street': street,
    'city': city,
    'state': state,
    'zip_code': zipCode,
    'country': country,
    'label': label,
    'is_default': isDefault,
    'created_at': createdAt?.toIso8601String(),
  };

  Address copyWith({
    String? id,
    String? userId,
    String? street,
    String? city,
    String? state,
    String? zipCode,
    String? country,
    String? label,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return Address(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      street: street ?? this.street,
      city: city ?? this.city,
      state: state ?? this.state,
      zipCode: zipCode ?? this.zipCode,
      country: country ?? this.country,
      label: label ?? this.label,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class AddressProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;
  List<Address> _addresses = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Address> get addresses => _addresses;

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<bool> fetchAddresses(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _supabase
          .from('addresses')
          .select('id, user_id, street, city, state, zip_code, country, label, is_default, created_at')
          .eq('user_id', userId)
          .order('is_default', ascending: false)
          .order('created_at', ascending: false);

      _addresses = (data as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((d) => Address.fromJson(d))
          .toList();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to fetch addresses: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> addAddress(Address address) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _supabase.from('addresses').insert(address.toJson());
      await fetchAddresses(address.userId);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to add address: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateAddress(Address address) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _supabase
          .from('addresses')
          .update(address.toJson())
          .eq('id', address.id!);
      await fetchAddresses(address.userId);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update address: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAddress(String addressId, String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _supabase.from('addresses').delete().eq('id', addressId);
      await fetchAddresses(userId);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete address: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> setDefaultAddress(String addressId, String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _supabase
          .from('addresses')
          .update({'is_default': false})
          .eq('user_id', userId);

      await _supabase
          .from('addresses')
          .update({'is_default': true})
          .eq('id', addressId);

      await fetchAddresses(userId);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to set default address: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void reset() {
    _isLoading = false;
    _errorMessage = null;
    _addresses = [];
    notifyListeners();
  }
}
