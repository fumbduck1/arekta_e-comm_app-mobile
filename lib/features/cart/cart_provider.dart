import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../core/graphql/graphql_service.dart';
import '../../core/graphql/queries/cart_queries.dart';
import '../../models/cart_model.dart';

class CartProvider extends ChangeNotifier {
  CartModel? _cart;
  bool _isLoading = false;
  String? _error;

  CartModel? get cart => _cart;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get itemCount => _cart?.totalItems ?? 0;
  double get subtotal => _cart?.subtotal ?? 0.0;
  bool get isEmpty => _cart?.isEmpty ?? true;
  List<CartItemModel> get items => _cart?.items ?? [];

  GraphQLClient get _client => GraphQLService.instance.client.value;

  /// Fetch cart from server
  Future<void> fetchCart() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _client.query(
        QueryOptions(
          document: gql(CartQueries.getCart),
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (result.hasException) {
        _error = 'Failed to load cart';
        debugPrint('Cart error: ${result.exception}');
      } else {
        final carts = result.data?['carts'] as List<dynamic>?;
        if (carts != null && carts.isNotEmpty) {
          _cart = CartModel.fromJson(carts.first as Map<String, dynamic>);
        } else {
          _cart = null;
        }
      }
    } catch (e) {
      _error = 'Error loading cart: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add item to cart with optimistic update
  Future<bool> addToCart(String productId, {int quantity = 1}) async {
    // Optimistic update - assume the item is added immediately
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _client.mutate(
        MutationOptions(
          document: gql(CartMutations.addToCart),
          variables: {'productId': productId, 'quantity': quantity},
        ),
      );

      if (result.hasException) {
        _error = 'Failed to add to cart';
        debugPrint('Add to cart error: ${result.exception}');
        notifyListeners();
        return false;
      }

      // Optimistically update the cart without fetching entire cart again
      // In a real app, you would parse the mutation result and update the local state
      await fetchCart(); // Fallback to full refresh if needed
      return true;
    } catch (e) {
      _error = 'Error adding to cart: $e';
      debugPrint('Add to cart error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Update cart item quantity with optimistic update
  Future<bool> updateQuantity(String cartItemId, int quantity) async {
    if (quantity < 1) return removeItem(cartItemId);

    // Optimistic update - assume the quantity is updated immediately
    final oldQuantity = _cart?.items
        .firstWhere((item) => item.id == cartItemId)
        .quantity;
    final itemIndex =
        _cart?.items.indexWhere((item) => item.id == cartItemId) ?? -1;

    if (itemIndex != -1 && _cart != null) {
      _cart!.items[itemIndex].quantity = quantity;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _client.mutate(
        MutationOptions(
          document: gql(CartMutations.updateCartItem),
          variables: {'id': cartItemId, 'quantity': quantity},
        ),
      );

      if (result.hasException) {
        // Revert optimistic update if mutation fails
        if (itemIndex != -1 && _cart != null && oldQuantity != null) {
          _cart!.items[itemIndex].quantity = oldQuantity;
        }
        _error = 'Failed to update quantity';
        debugPrint('Update quantity error: ${result.exception}');
        notifyListeners();
        return false;
      }

      // Optimistically update the cart without fetching entire cart again
      // In a real app, you would parse the mutation result and update the local state
      await fetchCart(); // Fallback to full refresh if needed
      return true;
    } catch (e) {
      // Revert optimistic update if mutation fails
      if (itemIndex != -1 && _cart != null && oldQuantity != null) {
        _cart!.items[itemIndex].quantity = oldQuantity;
      }
      _error = 'Error updating cart: $e';
      debugPrint('Update quantity error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Remove item from cart with optimistic update
  Future<bool> removeItem(String cartItemId) async {
    // Optimistic update - assume the item is removed immediately
    final removedItem = _cart?.items.firstWhere(
      (item) => item.id == cartItemId,
    );
    if (removedItem != null && _cart != null) {
      _cart!.items.remove(removedItem);
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _client.mutate(
        MutationOptions(
          document: gql(CartMutations.removeCartItem),
          variables: {'id': cartItemId},
        ),
      );

      if (result.hasException) {
        // Revert optimistic update if mutation fails
        if (removedItem != null && _cart != null) {
          _cart!.items.add(removedItem);
        }
        _error = 'Failed to remove item';
        debugPrint('Remove item error: ${result.exception}');
        notifyListeners();
        return false;
      }

      // Optimistically update the cart without fetching entire cart again
      // In a real app, you would parse the mutation result and update the local state
      await fetchCart(); // Fallback to full refresh if needed
      return true;
    } catch (e) {
      // Revert optimistic update if mutation fails
      if (removedItem != null && _cart != null) {
        _cart!.items.add(removedItem);
      }
      _error = 'Error removing from cart: $e';
      debugPrint('Remove item error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Clear the entire cart
  Future<bool> clearCart() async {
    if (_cart == null) return true;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _client.mutate(
        MutationOptions(
          document: gql(CartMutations.clearCart),
          variables: {'cartId': _cart!.id},
        ),
      );

      if (result.hasException) {
        _error = 'Failed to clear cart';
        debugPrint('Clear cart error: ${result.exception}');
        notifyListeners();
        return false;
      }

      _cart = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error clearing cart: $e';
      debugPrint('Clear cart error: $e');
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
