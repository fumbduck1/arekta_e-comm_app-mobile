class CarouselModel {
  final String id;
  final String? title;
  final String imageUrl;
  final String? linkType;
  final String? linkValue;
  final int sortOrder;

  const CarouselModel({
    required this.id,
    this.title,
    required this.imageUrl,
    this.linkType,
    this.linkValue,
    required this.sortOrder,
  });

  factory CarouselModel.fromJson(Map<String, dynamic> json) {
    return CarouselModel(
      id: json['id'] as String,
      title: json['title'] as String?,
      imageUrl: json['image_url'] as String,
      linkType: json['link_type'] as String?,
      linkValue: json['link_value'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}

class CouponModel {
  final String id;
  final String code;
  final String discountType; // 'percentage' or 'fixed'
  final double discountValue;
  final double? minOrder;
  final int? maxUses;
  final int usedCount;
  final String? vendorId;
  final DateTime? expiresAt;

  const CouponModel({
    required this.id,
    required this.code,
    required this.discountType,
    required this.discountValue,
    this.minOrder,
    this.maxUses,
    this.usedCount = 0,
    this.vendorId,
    this.expiresAt,
  });

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    return CouponModel(
      id: json['id'] as String,
      code: json['code'] as String,
      discountType: json['discount_type'] as String,
      discountValue: (json['discount_value'] as num).toDouble(),
      minOrder: (json['min_order'] as num?)?.toDouble(),
      maxUses: json['max_uses'] as int?,
      usedCount: json['used_count'] as int? ?? 0,
      vendorId: json['vendor_id'] as String?,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
    );
  }

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  bool get isUsedUp => maxUses != null && usedCount >= maxUses!;

  bool get isValid => !isExpired && !isUsedUp;

  bool get isPlatformWide => vendorId == null;

  bool get isPercentage => discountType == 'percentage';
}
