/// GraphQL query and mutation strings for Orders
class OrderQueries {
  OrderQueries._();

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

  /// Create a new order from the current cart
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
