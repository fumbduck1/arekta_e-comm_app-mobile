import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../core/graphql/graphql_service.dart';

/// Address model for shipping addresses
class Address {
  final String? id;
  final String userId;
  final String street;
  final String city;
  final String state;
  final String zipCode;
  final String country;
  final String? label; // e.g., "Home", "Work"
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

/// Provider for managing user shipping addresses
class AddressProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;
  List<Address> _addresses = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Address> get addresses => _addresses;

  /// Fetch all addresses for a user
  Future<bool> fetchAddresses(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      const query = '''
        query GetUserAddresses(\$userId: uuid!) {
          addresses(where: {user_id: {_eq: \$userId}}, order_by: [{is_default: desc}, {created_at: desc}]) {
            id
            user_id
            street
            city
            state
            zip_code
            country
            label
            is_default
            created_at
          }
        }
      ''';

      final result = await GraphQLService.instance.client.value.query(
        QueryOptions(document: gql(query), variables: {'userId': userId}),
      );

      if (result.hasException) {
        _errorMessage = result.exception.toString();
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (result.data == null) {
        _addresses = [];
        _isLoading = false;
        notifyListeners();
        return true;
      }

      final addressesData = result.data!['addresses'] as List?;
      if (addressesData != null) {
        _addresses = addressesData
            .cast<Map<String, dynamic>>()
            .map((data) => Address.fromJson(data))
            .toList();
      } else {
        _addresses = [];
      }

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

  /// Add a new address
  Future<bool> addAddress(Address address) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      const mutation = '''
        mutation AddAddress(
          \$userId: uuid!
          \$street: String!
          \$city: String!
          \$state: String!
          \$zipCode: String!
          \$country: String!
          \$label: String
          \$isDefault: Boolean
        ) {
          insert_addresses_one(object: {
            user_id: \$userId
            street: \$street
            city: \$city
            state: \$state
            zip_code: \$zipCode
            country: \$country
            label: \$label
            is_default: \$isDefault
          }) {
            id
            user_id
            street
            city
            state
            zip_code
            country
            label
            is_default
            created_at
          }
        }
      ''';

      final result = await GraphQLService.instance.client.value.mutate(
        MutationOptions(
          document: gql(mutation),
          variables: {
            'userId': address.userId,
            'street': address.street,
            'city': address.city,
            'state': address.state,
            'zipCode': address.zipCode,
            'country': address.country,
            'label': address.label,
            'isDefault': address.isDefault,
          },
        ),
      );

      if (result.hasException) {
        _errorMessage = result.exception.toString();
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Refresh addresses list
      await fetchAddresses(address.userId);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to add address: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Update an existing address
  Future<bool> updateAddress(Address address) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      const mutation = '''
        mutation UpdateAddress(
          \$id: uuid!
          \$street: String!
          \$city: String!
          \$state: String!
          \$zipCode: String!
          \$country: String!
          \$label: String
          \$isDefault: Boolean
        ) {
          update_addresses_by_pk(
            pk_columns: {id: \$id}
            _set: {
              street: \$street
              city: \$city
              state: \$state
              zip_code: \$zipCode
              country: \$country
              label: \$label
              is_default: \$isDefault
            }
          ) {
            id
            user_id
            street
            city
            state
            zip_code
            country
            label
            is_default
            created_at
          }
        }
      ''';

      final result = await GraphQLService.instance.client.value.mutate(
        MutationOptions(
          document: gql(mutation),
          variables: {
            'id': address.id,
            'street': address.street,
            'city': address.city,
            'state': address.state,
            'zipCode': address.zipCode,
            'country': address.country,
            'label': address.label,
            'isDefault': address.isDefault,
          },
        ),
      );

      if (result.hasException) {
        _errorMessage = result.exception.toString();
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Refresh addresses list
      await fetchAddresses(address.userId);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update address: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Delete an address
  Future<bool> deleteAddress(String addressId, String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      const mutation = '''
        mutation DeleteAddress(\$id: uuid!) {
          delete_addresses_by_pk(id: \$id) {
            id
          }
        }
      ''';

      final result = await GraphQLService.instance.client.value.mutate(
        MutationOptions(document: gql(mutation), variables: {'id': addressId}),
      );

      if (result.hasException) {
        _errorMessage = result.exception.toString();
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Refresh addresses list
      await fetchAddresses(userId);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete address: $e';
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

  /// Reset provider state
  void reset() {
    _isLoading = false;
    _errorMessage = null;
    _addresses = [];
    notifyListeners();
  }
}
