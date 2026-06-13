class SubscriptionPlan {
  final String id;
  final String name;
  final String? description;
  final double price;
  final String interval;
  final int maxVendors;
  final int maxProducts;
  final List<String> features;
  final bool isActive;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.interval,
    required this.maxVendors,
    required this.maxProducts,
    this.features = const [],
    this.isActive = true,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    final rawFeatures = json['features'];
    List<String> featuresList = [];
    if (rawFeatures is List) {
      featuresList = rawFeatures.map((e) => e.toString()).toList();
    }

    return SubscriptionPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      interval: json['interval'] as String? ?? 'monthly',
      maxVendors: (json['max_vendors'] as num?)?.toInt() ?? 5,
      maxProducts: (json['max_products'] as num?)?.toInt() ?? 100,
      features: featuresList,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  String get priceFormatted {
    if (price == 0) return 'Free';
    return '\u09F3${price.toStringAsFixed(2)}/${interval == 'yearly' ? 'yr' : 'mo'}';
  }
}

class MarketplaceSubscription {
  final String id;
  final String marketplaceId;
  final String planId;
  final String status;
  final DateTime currentPeriodStart;
  final DateTime currentPeriodEnd;
  final DateTime? cancelledAt;
  final String? paymentMethod;
  final String? paymentTrxId;

  const MarketplaceSubscription({
    required this.id,
    required this.marketplaceId,
    required this.planId,
    required this.status,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    this.cancelledAt,
    this.paymentMethod,
    this.paymentTrxId,
  });

  factory MarketplaceSubscription.fromJson(Map<String, dynamic> json) {
    return MarketplaceSubscription(
      id: json['id'] as String,
      marketplaceId: json['marketplace_id'] as String,
      planId: json['plan_id'] as String,
      status: json['status'] as String? ?? 'active',
      currentPeriodStart: DateTime.parse(json['current_period_start'] as String),
      currentPeriodEnd: DateTime.parse(json['current_period_end'] as String),
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'] as String)
          : null,
      paymentMethod: json['payment_method'] as String?,
      paymentTrxId: json['payment_trx_id'] as String?,
    );
  }

  bool get isActive => status == 'active';
  bool get isExpired => status == 'expired' || currentPeriodEnd.isBefore(DateTime.now());
}
