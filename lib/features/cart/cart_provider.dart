import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  List<CartItemModel> get items => _cart != null
      ? List<CartItemModel>.unmodifiable(_cart!.items)
      : [];

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<String?> _ensureCartId() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return null;
    }

    final result = await _supabase
        .from('carts')
        .upsert({'user_id': userId}, onConflict: 'user_id')
        .select('id')
        .single();

    return result['id'] as String;
  }

  Future<void> fetchCart() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _cart = null;
        return;
      }

      final carts = await _supabase
          .from('carts')
          .select(
            'id, cart_items(id, quantity, product:products(id, name, description, price, sale_price, stock, images, is_active, created_at))',
          )
          .eq('user_id', userId)
          .limit(1);

      if (carts.isNotEmpty) {
        _cart = CartModel.fromJson(carts.first);
      } else {
        _cart = null;
      }
    } catch (e) {
      _error = 'Failed to load cart';
      debugPrint('Cart error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addToCart(String productId, {int quantity = 1}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final cartId = await _ensureCartId();
      if (cartId == null) {
        _error = 'Please sign in to add items to cart';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final product = await _supabase
          .from('products')
          .select('stock')
          .eq('id', productId)
          .single();

      final stock = (product['stock'] as num?)?.toInt() ?? 0;
      if (stock < quantity) {
        _error = 'Only $stock items available in stock';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final existingItem = await _supabase
          .from('cart_items')
          .select('id, quantity')
          .eq('cart_id', cartId)
          .eq('product_id', productId)
          .maybeSingle();

      if (existingItem != null) {
        final existingQty = (existingItem['quantity'] as num?)?.toInt() ?? 0;
        final newQty = existingQty + quantity;
        if (newQty > stock) {
          _error = 'Only ${stock - existingQty} more items available in stock';
          _isLoading = false;
          notifyListeners();
          return false;
        }
        await _supabase
            .from('cart_items')
            .update({'quantity': newQty})
            .eq('id', existingItem['id'] as String);
      } else {
        await _supabase.from('cart_items').insert({
          'cart_id': cartId,
          'product_id': productId,
          'quantity': quantity,
        });
      }

      await _supabase
          .from('carts')
          .update({'updated_at': DateTime.now().toIso8601String()})
          .eq('id', cartId);

      await fetchCart();
      return true;
    } catch (e) {
      _error = 'Failed to add to cart';
      debugPrint('Add to cart error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateQuantity(String cartItemId, int quantity) async {
    if (quantity < 1) return removeItem(cartItemId);

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
      await _supabase
          .from('cart_items')
          .update({'quantity': quantity})
          .eq('id', cartItemId);

      await fetchCart();
      return true;
    } catch (e) {
      if (itemIndex != -1 && _cart != null && oldQuantity != null) {
        _cart!.items[itemIndex].quantity = oldQuantity;
      }
      _error = 'Failed to update cart';
      debugPrint('Update quantity error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeItem(String cartItemId) async {
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
      await _supabase.from('cart_items').delete().eq('id', cartItemId);

      await fetchCart();
      return true;
    } catch (e) {
      if (removedItem != null && _cart != null) {
        _cart!.items.add(removedItem);
      }
      _error = 'Failed to remove from cart';
      debugPrint('Remove item error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> clearCart() async {
    if (_cart == null) return true;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _supabase.from('cart_items').delete().eq('cart_id', _cart!.id);

      _cart = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to clear cart';
      debugPrint('Clear cart error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
