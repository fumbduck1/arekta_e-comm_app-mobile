/// GraphQL query and mutation strings for Orders
class OrderQueries {
  OrderQueries._();

  /// OPTIMIZED: Get user purchase history using view
  /// Replaces multiple JOINs with single aggregated view query
  static const String getUserPurchaseHistory = r'''
    query GetUserPurchaseHistory(
      $userId: uuid!,
      $limit: Int,
      $offset: Int
    ) {
      vw_user_purchase_history(
        where: { user_id: { _eq: $userId } },
        limit: $limit,
        offset: $offset,
        order_by: { created_at: desc }
      ) {
        order_id
        user_id
        status
        total_amount
        payment_status
        payment_id
        shipping_address
        created_at
        updated_at
        item_count
        items
      }
      vw_user_purchase_history_aggregate(
        where: { user_id: { _eq: $userId } }
      ) {
        aggregate {
          count
        }
      }
    }
  ''';

  /// OPTIMIZED: Get order timeline using view
  static const String getOrderTimeline = r'''
    query GetOrderTimeline($userId: uuid!) {
      vw_order_timeline(
        where: { user_id: { _eq: $userId } },
        order_by: { order_created_at: desc }
      ) {
        order_id
        user_id
        order_created_at
        order_updated_at
        order_status
        total_amount
        payment_status
        shipping_address
        item_count
        vendor_count
        items
        fulfillment_time
      }
    }
  ''';

  /// Get current user's orders
  static const String getOrders = r'''
    query GetOrders($limit: Int!, $offset: Int!, $status: String) {
      orders(
        limit: $limit,
        offset: $offset,
        where: { status: { _eq: $status } },
        order_by: { created_at: desc }
      ) {
        id
        status
        total_amount
        payment_status
        shipping_address
        created_at
        order_items {
          id
          quantity
          unit_price: price_at_purchase
          status
          product {
            id
            name
            images
          }
          vendor {
            id
            shop_name
          }
        }
      }
      orders_aggregate(where: { status: { _eq: $status } }) {
        aggregate {
          count
        }
      }
    }
  ''';

  /// Get single order detail
  static const String getOrderById = r'''
    query GetOrderById($id: uuid!) {
      orders_by_pk(id: $id) {
        id
        status
        total_amount
        payment_status
        payment_transaction_id: payment_id
        shipping_address
        created_at
        order_items {
          id
          quantity
          unit_price: price_at_purchase
          status
          product {
            id
            name
            images
            price
          }
          vendor {
            id
            shop_name
          }
        }
      }
    }
  ''';

  /// Vendor: get order items assigned to this vendor
  static const String getVendorOrderItems = r'''
    query GetVendorOrderItems($limit: Int!, $offset: Int!, $status: String) {
      order_items(
        limit: $limit,
        offset: $offset,
        where: { status: { _eq: $status } },
        order_by: { order: { created_at: desc } }
      ) {
        id
        quantity
        unit_price: price_at_purchase
        status
        product {
          id
          name
          images
        }
        order {
          id
          status
          shipping_address
          created_at
          user {
            name
            phone
          }
        }
      }
    }
  ''';
}

/// GraphQL query for coupon validation
class CouponQueries {
  CouponQueries._();

  /// OPTIMIZED: Validate coupon using procedure
  static const String validateCoupon = r'''
    query ValidateCoupon($code: String!, $orderSubtotal: numeric!) {
      validate_coupon_for_order(
        p_coupon_code: $code,
        p_order_subtotal: $orderSubtotal
      ) {
        is_valid
        reason
        discount_amount
      }
    }
  ''';

  /// Get active coupons for user
  static const String getActiveCoupons = r'''
    query GetActiveCoupons($orderSubtotal: numeric) {
      get_active_coupons_for_user(p_order_subtotal: $orderSubtotal) {
        coupon_id
        code
        discount_type
        discount_value
        min_order
        expires_at
        usage_remaining
        description
      }
    }
  ''';

  /// Look up a coupon by code
  static const String getCouponByCode = r'''
    query GetCouponByCode($code: String!) {
      coupons(where: { code: { _eq: $code }, is_active: { _eq: true } }, limit: 1) {
        id
        code
        discount_type
        discount_value
        min_order
        max_uses
        used_count
        vendor_id
        expires_at
      }
    }
  ''';
}

class OrderMutations {
  OrderMutations._();

  /// OPTIMIZED: Create order from cart using atomic procedure
  /// Replaces multiple API calls with single transaction
  /// Handles: stock validation, coupon processing, cart clearing
  static const String createOrderFromCart = r'''
    mutation CreateOrderFromCart(
      $userId: uuid!,
      $shippingAddress: String!,
      $paymentMethod: String!,
      $couponCode: String
    ) {
      create_order_from_cart(
        p_user_id: $userId,
        p_shipping_address: $shippingAddress,
        p_payment_method: $paymentMethod,
        p_coupon_code: $couponCode
      ) {
        order_id
        total_amount
        coupon_discount
        status
        message
      }
    }
  ''';

  /// Create a new order from the current cart (legacy)
  static const String createOrder = r'''
    mutation CreateOrder(
      $shippingAddress: String!,
      $paymentMethod: String!,
      $couponId: uuid,
      $couponDiscount: numeric
    ) {
      insert_orders_one(object: {
        shipping_address: $shippingAddress,
        payment_method: $paymentMethod,
        coupon_id: $couponId,
        coupon_discount: $couponDiscount
      }) {
        id
        status
      }
    }
  ''';

  /// Cancel an order (client)
  static const String cancelOrder = r'''
    mutation CancelOrder($id: uuid!) {
      update_orders_by_pk(
        pk_columns: { id: $id },
        _set: { status: "cancelled" }
      ) {
        id
        status
      }
    }
  ''';

  /// Update order item status (vendor)
  static const String updateOrderItemStatus = r'''
    mutation UpdateOrderItemStatus($id: uuid!, $status: String!) {
      update_order_items_by_pk(
        pk_columns: { id: $id },
        _set: { status: $status }
      ) {
        id
        status
      }
    }
  ''';
}
