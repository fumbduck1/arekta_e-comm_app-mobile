/// Order status lifecycle
enum OrderStatus {
  pending,
  confirmed,
  processing,
  shipped,
  delivered,
  cancelled;

  static OrderStatus fromString(String value) {
    return OrderStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => OrderStatus.pending,
    );
  }
}

class OrderModel {
  final String id;
  final OrderStatus status;
  final double totalAmount;
  final String? paymentStatus;
  final String? paymentTransactionId;
  final Map<String, dynamic>? shippingAddress;
  final DateTime createdAt;
  final List<OrderItemModel> items;

  const OrderModel({
    required this.id,
    required this.status,
    required this.totalAmount,
    this.paymentStatus,
    this.paymentTransactionId,
    this.shippingAddress,
    required this.createdAt,
    required this.items,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final itemsList =
        (json['order_items'] as List<dynamic>?)
            ?.map((e) => OrderItemModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return OrderModel(
      id: json['id'] as String,
      status: OrderStatus.fromString(json['status'] as String),
      totalAmount: (json['total_amount'] as num).toDouble(),
      paymentStatus: json['payment_status'] as String?,
      paymentTransactionId:
          (json['payment_transaction_id'] ?? json['payment_id']) as String?,
      shippingAddress: _parseShippingAddress(json['shipping_address']),
      createdAt: DateTime.parse(json['created_at'] as String),
      items: itemsList,
    );
  }

  static Map<String, dynamic>? _parseShippingAddress(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is String) return {'formatted': value};
    return null;
  }

  bool get canCancel => status == OrderStatus.pending;
}

class OrderItemModel {
  final String id;
  final int quantity;
  final double unitPrice;
  final String? status;
  final OrderItemProduct? product;
  final OrderItemVendor? vendor;

  const OrderItemModel({
    required this.id,
    required this.quantity,
    required this.unitPrice,
    this.status,
    this.product,
    this.vendor,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id'] as String,
      quantity: json['quantity'] as int,
      unitPrice: ((json['unit_price'] ?? json['price_at_purchase']) as num)
          .toDouble(),
      status: json['status'] as String?,
      product: json['product'] != null
          ? OrderItemProduct.fromJson(json['product'] as Map<String, dynamic>)
          : null,
      vendor: json['vendor'] != null
          ? OrderItemVendor.fromJson(json['vendor'] as Map<String, dynamic>)
          : null,
    );
  }

  double get lineTotal => unitPrice * quantity;
}

class OrderItemProduct {
  final String id;
  final String name;
  final List<String> images;

  const OrderItemProduct({
    required this.id,
    required this.name,
    required this.images,
  });

  factory OrderItemProduct.fromJson(Map<String, dynamic> json) {
    final rawImages = json['images'];
    List<String> imageList = [];
    if (rawImages is List) {
      imageList = rawImages.map((e) => e.toString()).toList();
    }
    return OrderItemProduct(
      id: json['id'] as String,
      name: json['name'] as String,
      images: imageList,
    );
  }

  String get primaryImage =>
      images.isNotEmpty ? images.first : 'https://via.placeholder.com/100';
}

class OrderItemVendor {
  final String id;
  final String shopName;

  const OrderItemVendor({required this.id, required this.shopName});

  factory OrderItemVendor.fromJson(Map<String, dynamic> json) {
    return OrderItemVendor(
      id: json['id'] as String,
      shopName: json['shop_name'] as String,
    );
  }
}
