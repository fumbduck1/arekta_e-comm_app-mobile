/// GraphQL query and mutation strings for Cart
class CartQueries {
  CartQueries._();

  /// Get current user's cart with items
  static const String getCart = r'''
    query GetCart {
      carts(limit: 1) {
        id
        cart_items {
          id
          quantity
          product {
            id
            name
            price
            compare_at_price: sale_price
            stock_qty: stock
            images
            vendor {
              id
              shop_name
            }
          }
        }
      }
    }
  ''';
}

class CartMutations {
  CartMutations._();

  /// Add item to cart (upsert — if item exists, increment qty)
  static const String addToCart = r'''
    mutation AddToCart($productId: uuid!, $quantity: Int!) {
      insert_cart_items_one(
        object: {
          product_id: $productId,
          quantity: $quantity,
          cart: {
            data: {},
            on_conflict: {
              constraint: carts_user_id_key,
              update_columns: [updated_at]
            }
          }
        },
        on_conflict: {
          constraint: cart_items_cart_id_product_id_key,
          update_columns: [quantity]
        }
      ) {
        id
        quantity
      }
    }
  ''';

  /// Update cart item quantity
  static const String updateCartItem = r'''
    mutation UpdateCartItem($id: uuid!, $quantity: Int!) {
      update_cart_items_by_pk(
        pk_columns: { id: $id },
        _set: { quantity: $quantity }
      ) {
        id
        quantity
      }
    }
  ''';

  /// Remove item from cart
  static const String removeCartItem = r'''
    mutation RemoveCartItem($id: uuid!) {
      delete_cart_items_by_pk(id: $id) {
        id
      }
    }
  ''';

  /// Clear entire cart
  static const String clearCart = r'''
    mutation ClearCart($cartId: uuid!) {
      delete_cart_items(where: { cart_id: { _eq: $cartId } }) {
        affected_rows
      }
    }
  ''';
}
