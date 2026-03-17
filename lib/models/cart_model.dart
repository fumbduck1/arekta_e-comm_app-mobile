import 'product_model.dart';

class CartModel {
  final String id;
  final List<CartItemModel> items;

  const CartModel({required this.id, required this.items});

  factory CartModel.fromJson(Map<String, dynamic> json) {
    final itemsList =
        (json['cart_items'] as List<dynamic>?)
            ?.map((e) => CartItemModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return CartModel(id: json['id'] as String, items: itemsList);
  }

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.lineTotal);

  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);

  bool get isEmpty => items.isEmpty;
}

class CartItemModel {
  final String id;
  int quantity;
  final ProductModel product;

  CartItemModel({
    required this.id,
    required this.quantity,
    required this.product,
  });

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    return CartItemModel(
      id: json['id'] as String,
      quantity: json['quantity'] as int,
      product: ProductModel.fromJson(json['product'] as Map<String, dynamic>),
    );
  }

  double get lineTotal => product.price * quantity;
}
