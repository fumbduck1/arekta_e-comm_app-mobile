class ProductModel {
  final String id;
  final String name;
  final String? slug;
  final String? description;
  final double price;
  final double? compareAtPrice;
  final int stockQty;
  final List<String> images;
  final bool isActive;
  final DateTime createdAt;
  final ProductCategory? category;
  final ProductVendor? vendor;
  final double? avgRating;
  final int reviewCount;

  const ProductModel({
    required this.id,
    required this.name,
    this.slug,
    this.description,
    required this.price,
    this.compareAtPrice,
    required this.stockQty,
    required this.images,
    this.isActive = true,
    required this.createdAt,
    this.category,
    this.vendor,
    this.avgRating,
    this.reviewCount = 0,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    // Parse images from JSONB (could be a list of strings)
    final rawImages = json['images'];
    List<String> imageList = [];
    if (rawImages is List) {
      imageList = rawImages.map((e) => e.toString()).toList();
    }

    // Parse review aggregate
    double? avgRating;
    int reviewCount = 0;
    final agg = json['reviews_aggregate']?['aggregate'];
    if (agg != null) {
      avgRating = (agg['avg']?['rating'] as num?)?.toDouble();
      reviewCount = (agg['count'] as num?)?.toInt() ?? 0;
    }

    return ProductModel(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String?,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      compareAtPrice:
          ((json['compare_at_price'] ?? json['sale_price']) as num?)
              ?.toDouble(),
      stockQty: ((json['stock_qty'] ?? json['stock']) as num?)?.toInt() ?? 0,
      images: imageList,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      category: json['category'] != null
          ? ProductCategory.fromJson(json['category'] as Map<String, dynamic>)
          : null,
      vendor: json['vendor'] != null
          ? ProductVendor.fromJson(json['vendor'] as Map<String, dynamic>)
          : null,
      avgRating: avgRating,
      reviewCount: reviewCount,
    );
  }

  String get primaryImage =>
      images.isNotEmpty ? images.first : 'https://via.placeholder.com/300';

  bool get isOnSale => compareAtPrice != null && compareAtPrice! > price;

  double get discountPercentage {
    if (!isOnSale) return 0;
    return ((compareAtPrice! - price) / compareAtPrice! * 100);
  }

  bool get inStock => stockQty > 0;
}

class ProductCategory {
  final String id;
  final String name;
  final String? slug;

  const ProductCategory({required this.id, required this.name, this.slug});

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    return ProductCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String?,
    );
  }
}

class ProductVendor {
  final String id;
  final String shopName;
  final String? logoUrl;
  final double? ratingAvg;

  const ProductVendor({
    required this.id,
    required this.shopName,
    this.logoUrl,
    this.ratingAvg,
  });

  factory ProductVendor.fromJson(Map<String, dynamic> json) {
    return ProductVendor(
      id: json['id'] as String,
      shopName: json['shop_name'] as String,
      logoUrl: json['logo_url'] as String?,
      ratingAvg: _extractVendorRatingAvg(json),
    );
  }

  static double? _extractVendorRatingAvg(Map<String, dynamic> json) {
    final direct = json['rating_avg'];
    if (direct is num) return direct.toDouble();

    final reviewsAggregate = json['reviews_aggregate'];
    if (reviewsAggregate is Map<String, dynamic>) {
      final avg = reviewsAggregate['aggregate'];
      if (avg is Map<String, dynamic>) {
        final rating = avg['avg'];
        if (rating is Map<String, dynamic>) {
          final value = rating['rating'];
          if (value is num) return value.toDouble();
        }
      }
    }

    final products = json['products'];
    if (products is List) {
      double weightedSum = 0;
      int totalCount = 0;

      for (final item in products) {
        if (item is! Map<String, dynamic>) continue;
        final aggregate = item['reviews_aggregate'];
        if (aggregate is! Map<String, dynamic>) continue;
        final aggregateBody = aggregate['aggregate'];
        if (aggregateBody is! Map<String, dynamic>) continue;

        final count = (aggregateBody['count'] as num?)?.toInt() ?? 0;
        final avg = aggregateBody['avg'];
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
