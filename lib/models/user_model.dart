import 'package:flutter/foundation.dart';

import '../core/constants/enums.dart';

// ── Supertype ───────────────────────────────────────────────
/// Base user entity. Subtypes: [ClientUser], [VendorUser], [AdminUser].
/// Specialization is disjoint & total — every user is exactly one subtype.
class UserModel {
  final String id;
  final String email;
  final String? name;
  final String? phone;
  final UserRole role;
  final String? avatarUrl;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.email,
    this.name,
    this.phone,
    required this.role,
    this.avatarUrl,
    required this.createdAt,
  });

  /// Factory that returns the correct subtype based on role.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    try {
      final roleString = json['role'] as String? ?? 'client';
      final role = UserRole.fromString(roleString);

      final id = json['id'] as String? ?? '';
      final email = json['email'] as String? ?? '';
      final name = json['name'] as String?;
      final phone = json['phone'] as String?;
      final avatarUrl = json['avatar_url'] as String?;

      DateTime createdAt;
      try {
        createdAt = DateTime.parse(
          json['created_at'] as String? ?? DateTime.now().toIso8601String(),
        );
      } catch (e) {
        createdAt = DateTime.now();
      }

      switch (role) {
        case UserRole.vendor:
          return VendorUser(
            id: id,
            email: email,
            name: name,
            phone: phone,
            avatarUrl: avatarUrl,
            createdAt: createdAt,
            vendorProfile: json['vendor'] != null && json['vendor'] is Map
                ? VendorModel.fromJson(json['vendor'] as Map<String, dynamic>)
                : null,
          );
        case UserRole.superAdmin:
          return AdminUser(
            id: id,
            email: email,
            name: name,
            phone: phone,
            avatarUrl: avatarUrl,
            createdAt: createdAt,
          );
        case UserRole.client:
          return ClientUser(
            id: id,
            email: email,
            name: name,
            phone: phone,
            avatarUrl: avatarUrl,
            createdAt: createdAt,
          );
      }
    } catch (e) {
      debugPrint('[UserModel] Error parsing JSON: $e');
      // Return a default client user if parsing fails
      return ClientUser(id: '', email: '', createdAt: DateTime.now());
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'phone': phone,
    'role': role.hasuraRole,
    'avatar_url': avatarUrl,
    'created_at': createdAt.toIso8601String(),
  };

  /// Subtype checks — prefer `is` checks (e.g. `user is VendorUser`).
  bool get isVendor => this is VendorUser;
  bool get isAdmin => this is AdminUser;
  bool get isClient => this is ClientUser;

  /// Convenience: access vendor profile if this is a VendorUser.
  VendorModel? get vendor =>
      this is VendorUser ? (this as VendorUser).vendorProfile : null;
}

// ── Subtype: Client ─────────────────────────────────────────
/// Regular shopper. Can browse, cart, order, review.
class ClientUser extends UserModel {
  const ClientUser({
    required super.id,
    required super.email,
    super.name,
    super.phone,
    super.avatarUrl,
    required super.createdAt,
  }) : super(role: UserRole.client);
}

// ── Subtype: Vendor ─────────────────────────────────────────
/// Vendor user. Has an associated VendorModel (shop profile).
/// Can manage products, fulfill order items, create coupons.
class VendorUser extends UserModel {
  final VendorModel? vendorProfile;

  const VendorUser({
    required super.id,
    required super.email,
    super.name,
    super.phone,
    super.avatarUrl,
    required super.createdAt,
    this.vendorProfile,
  }) : super(role: UserRole.vendor);

  /// Convenience alias
  @override
  VendorModel? get vendor => vendorProfile;
}

// ── Subtype: Admin ──────────────────────────────────────────
/// Super admin. Can approve vendors, upload carousels,
/// view all orders/payments, manage categories.
class AdminUser extends UserModel {
  const AdminUser({
    required super.id,
    required super.email,
    super.name,
    super.phone,
    super.avatarUrl,
    required super.createdAt,
  }) : super(role: UserRole.superAdmin);
}

// ── Vendor Profile (associated entity) ──────────────────────
class VendorModel {
  final String id;
  final String shopName;
  final String? shopDescription;
  final String? logoUrl;
  final bool isApproved;
  final double? ratingAvg;
  final DateTime createdAt;

  const VendorModel({
    required this.id,
    required this.shopName,
    this.shopDescription,
    this.logoUrl,
    required this.isApproved,
    this.ratingAvg,
    required this.createdAt,
  });

  factory VendorModel.fromJson(Map<String, dynamic> json) {
    return VendorModel(
      id: json['id'] as String,
      shopName: json['shop_name'] as String,
      shopDescription:
          (json['description'] ?? json['shop_description']) as String?,
      logoUrl: json['logo_url'] as String?,
      isApproved: json['is_approved'] as bool? ?? false,
      ratingAvg: _extractRatingAvg(json),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static double? _extractRatingAvg(Map<String, dynamic> json) {
    final direct = json['rating_avg'];
    if (direct is num) return direct.toDouble();

    final reviewsAggregate = json['reviews_aggregate'];
    if (reviewsAggregate is Map<String, dynamic>) {
      final aggregate = reviewsAggregate['aggregate'];
      if (aggregate is Map<String, dynamic>) {
        final avg = aggregate['avg'];
        if (avg is Map<String, dynamic>) {
          final rating = avg['rating'];
          if (rating is num) return rating.toDouble();
        }
      }
    }

    final products = json['products'];
    if (products is List) {
      double weightedSum = 0;
      int totalCount = 0;

      for (final item in products) {
        if (item is! Map<String, dynamic>) continue;
        final reviewsAggregate = item['reviews_aggregate'];
        if (reviewsAggregate is! Map<String, dynamic>) continue;
        final aggregate = reviewsAggregate['aggregate'];
        if (aggregate is! Map<String, dynamic>) continue;

        final count = (aggregate['count'] as num?)?.toInt() ?? 0;
        final avg = aggregate['avg'];
        final rating = avg is Map<String, dynamic>
            ? (avg['rating'] as num?)?.toDouble()
            : null;

        if (rating != null && count > 0) {
          weightedSum += rating * count;
          totalCount += count;
        }
      }

      if (totalCount > 0) {
        return weightedSum / totalCount;
      }
    }

    return null;
  }
}
