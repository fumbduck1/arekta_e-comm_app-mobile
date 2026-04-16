/// GraphQL queries and mutations for Admin features
class AdminQueries {
  AdminQueries._();

  /// OPTIMIZED: Get admin dashboard metrics using pre-aggregated view
  /// Replaces ~15 separate queries with single view query
  static const String getDashboardMetrics = r'''
    query GetDashboardMetrics {
      vw_admin_dashboard_metrics {
        total_users
        total_vendors
        approved_vendors
        pending_vendors
        total_products
        active_products
        pending_moderation
        rejected_products
        total_orders
        total_revenue
        delivered_orders
        pending_orders
        paid_orders
        unpaid_orders
        active_coupons
        coupons_used
        total_reviews
        avg_rating
      }
    }
  ''';

  /// OPTIMIZED: Get vendor analytics using view
  static const String getVendorAnalytics = r'''
    query GetVendorAnalytics($vendorId: uuid!) {
      vw_vendor_analytics(
        where: { vendor_id: { _eq: $vendorId } }
      ) {
        vendor_id
        shop_name
        is_approved
        vendor_created_at
        vendor_email
        vendor_name
        vendor_phone
        total_products
        active_products
        pending_moderation
        rejected_products
        total_orders
        total_sales
        total_items_sold
        pending_fulfillment
        delivered_orders
        avg_product_rating
        total_reviews
        last_sale_date
        days_since_last_sale
      }
    }
  ''';

  /// OPTIMIZED: Get inventory alerts using view
  static const String getInventoryAlerts = r'''
    query GetInventoryAlerts($vendorId: uuid) {
      vw_inventory_alerts(
        where: { vendor_id: { _eq: $vendorId } },
        order_by: { alert_priority: asc }
      ) {
        id
        name
        price
        sale_price
        stock
        images
        vendor_id
        shop_name
        vendor_email
        stock_status
        alert_priority
        created_at
        updated_at
      }
    }
  ''';

  /// OPTIMIZED: Get pending vendor approvals using view
  static const String getPendingVendorApprovals = r'''
    query GetPendingVendorApprovals {
      vw_pending_vendor_approvals {
        vendor_id
        user_id
        shop_name
        description
        logo_url
        is_approved
        created_at
        email
        name
        phone
        product_count
        vendor_status
      }
    }
  ''';

  /// OPTIMIZED: Get pending product moderation using view
  static const String getPendingProductModeration = r'''
    query GetPendingProductModeration {
      vw_pending_product_moderation(
        order_by: { created_at: asc }
      ) {
        id
        name
        description
        price
        sale_price
        stock
        images
        created_at
        moderation_status
        moderation_notes
        moderated_by
        moderated_at
        vendor_id
        shop_name
        vendor_user_id
        vendor_email
        vendor_name
        vendor_phone
        pending_duration
      }
    }
  ''';

  /// OPTIMIZED: Get customer spending analytics using view
  static const String getCustomerSpendingAnalytics = r'''
    query GetCustomerSpendingAnalytics(
      $limit: Int,
      $offset: Int
    ) {
      vw_customer_spending_analytics(
        limit: $limit,
        offset: $offset,
        order_by: { lifetime_spending: desc }
      ) {
        user_id
        email
        name
        phone
        customer_registered_date
        total_orders
        lifetime_spending
        average_order_value
        delivered_orders
        cancelled_orders
        last_purchase_date
        days_since_last_purchase
        reviews_written
      }
    }
  ''';

  /// Get all vendors with approval status
  static const String getVendors = r'''
    query GetVendors {
      vendors(order_by: { created_at: desc }) {
        id
        shop_name
        shop_description: description
        logo_url
        is_approved
        created_at
        user {
          id
          name
          email
          phone
        }
      }
    }
  ''';

  /// Get pending vendor approvals only
  static const String getPendingVendors = r'''
    query GetPendingVendors {
      vendors(
        where: { is_approved: { _eq: false } },
        order_by: { created_at: desc }
      ) {
        id
        user_id
        shop_name
        shop_description: description
        logo_url
        created_at
        user {
          id
          email
          name
          phone
          created_at
        }
      }
    }
  ''';

  /// Get all carousels (including inactive)
  static const String getCarousels = r'''
    query GetAllCarousels {
      carousels(order_by: { sort_order: asc }) {
        id
        title
        image_url
        link_type
        link_value
        sort_order
        is_active
      }
    }
  ''';

  /// Get all categories
  static const String getCategories = r'''
    query GetAllCategories {
      categories(order_by: { name: asc }) {
        id
        name
        slug
        image_url
        parent_id
      }
    }
  ''';

  /// Get all coupons
  static const String getCoupons = r'''
    query GetAllCoupons {
      coupons(order_by: { created_at: desc }) {
        id
        code
        discount_type
        discount_value
        min_order
        max_uses
        used_count
        vendor_id
        expires_at
        is_active
        created_at
      }
    }
  ''';

  /// Dashboard aggregate stats
  static const String getDashboardStats = r'''
    query GetDashboardStats {
      vendors_aggregate { aggregate { count } }
      orders_aggregate { aggregate { count } }
      orders_aggregate_revenue: orders_aggregate {
        aggregate { sum { total_amount } }
      }
    }
  ''';

  /// Dashboard datapoints for selected and previous periods
  static const String getDashboardInsights = r'''
    query GetDashboardInsights(
      $start: timestamptz!,
      $end: timestamptz!,
      $previousStart: timestamptz!,
      $previousEnd: timestamptz!
    ) {
      products_current: products(
        where: { created_at: { _gte: $start, _lt: $end } }
      ) {
        id
      }
      products_previous: products(
        where: { created_at: { _gte: $previousStart, _lt: $previousEnd } }
      ) {
        id
      }

      vendors_current: vendors(
        where: { created_at: { _gte: $start, _lt: $end } }
      ) {
        id
      }
      vendors_previous: vendors(
        where: { created_at: { _gte: $previousStart, _lt: $previousEnd } }
      ) {
        id
      }

      orders_current: orders(
        where: { created_at: { _gte: $start, _lt: $end } }
      ) {
        id
        total_amount
      }
      orders_previous: orders(
        where: { created_at: { _gte: $previousStart, _lt: $previousEnd } }
      ) {
        id
        total_amount
      }

      vendor_order_items: order_items(
        where: {
          _and: [
            { created_at: { _gte: $start, _lt: $end } },
            { status: { _neq: "cancelled" } }
          ]
        }
      ) {
        vendor_id
        order_id
        quantity
        price_at_purchase
        vendor {
          id
          shop_name
        }
      }
    }
  ''';

  /// Products requiring moderation (pending or previously rejected)
  static const String getPendingProducts = r'''
    query GetPendingProducts {
      products(
        where: { moderation_status: { _in: ["pending", "rejected"] } },
        order_by: { created_at: desc }
      ) {
        id
        name
        price
        stock
        moderation_status
        moderation_notes
        created_at
        vendor {
          id
          shop_name
          is_approved
        }
      }
    }
  ''';
}

class AdminMutations {
  AdminMutations._();

  /// OPTIMIZED: Approve/reject product using procedure (includes audit trail)
  static const String approveProductForSale = r'''
    mutation ApproveProductForSale(
      $productId: uuid!,
      $adminUserId: uuid!,
      $status: String!,
      $moderationNotes: String
    ) {
      approve_product_for_sale(
        p_product_id: $productId,
        p_admin_user_id: $adminUserId,
        p_status: $status,
        p_moderation_notes: $moderationNotes
      ) {
        product_id
        moderation_status
        is_active
        moderated_at
        affected_rows
        message
      }
    }
  ''';

  /// Approve or reject a vendor
  static const String updateVendorApproval = r'''
    mutation UpdateVendorApproval($id: uuid!, $isApproved: Boolean!) {
      update_vendors_by_pk(
        pk_columns: { id: $id },
        _set: { is_approved: $isApproved }
      ) {
        id
        is_approved
      }
    }
  ''';

  /// Toggle carousel active status
  static const String updateCarouselStatus = r'''
    mutation UpdateCarouselStatus($id: uuid!, $isActive: Boolean!) {
      update_carousels_by_pk(
        pk_columns: { id: $id },
        _set: { is_active: $isActive }
      ) {
        id
        is_active
      }
    }
  ''';

  /// Create a carousel banner
  static const String createCarousel = r'''
    mutation CreateCarousel(
      $title: String,
      $imageUrl: String!,
      $linkType: String,
      $linkValue: String,
      $sortOrder: Int!,
      $isActive: Boolean!
    ) {
      insert_carousels_one(object: {
        title: $title,
        image_url: $imageUrl,
        link_type: $linkType,
        link_value: $linkValue,
        sort_order: $sortOrder,
        is_active: $isActive
      }) {
        id
        image_url
      }
    }
  ''';

  /// Delete a carousel
  static const String deleteCarousel = r'''
    mutation DeleteCarousel($id: uuid!) {
      delete_carousels_by_pk(id: $id) { id }
    }
  ''';

  /// Create a category
  static const String createCategory = r'''
    mutation CreateCategory($name: String!, $slug: String!, $imageUrl: String, $parentId: uuid) {
      insert_categories_one(object: {
        name: $name,
        slug: $slug,
        image_url: $imageUrl,
        parent_id: $parentId
      }) {
        id
        name
        slug
      }
    }
  ''';

  /// Delete a category
  static const String deleteCategory = r'''
    mutation DeleteCategory($id: uuid!) {
      delete_categories_by_pk(id: $id) { id }
    }
  ''';

  /// Create a coupon
  static const String createCoupon = r'''
    mutation CreateCoupon(
      $code: String!,
      $discountType: String!,
      $discountValue: numeric!,
      $minOrder: numeric,
      $maxUses: Int,
      $expiresAt: timestamptz
    ) {
      insert_coupons_one(object: {
        code: $code,
        discount_type: $discountType,
        discount_value: $discountValue,
        min_order: $minOrder,
        max_uses: $maxUses,
        expires_at: $expiresAt,
        is_active: true
      }) {
        id
        code
      }
    }
  ''';

  /// Toggle coupon active status
  static const String updateCouponStatus = r'''
    mutation UpdateCouponStatus($id: uuid!, $isActive: Boolean!) {
      update_coupons_by_pk(
        pk_columns: { id: $id },
        _set: { is_active: $isActive }
      ) {
        id
        is_active
      }
    }
  ''';

  /// Delete a coupon
  static const String deleteCoupon = r'''
    mutation DeleteCoupon($id: uuid!) {
      delete_coupons_by_pk(id: $id) { id }
    }
  ''';

  /// Approve or reject a product — sets full audit trail.
  /// Pass: isActive=true + moderationStatus="approved" to approve.
  /// Pass: isActive=false + moderationStatus="rejected" to reject.
  /// The DB trigger also enforces these fields; the mutation ensures
  /// moderated_by is captured correctly from the admin user id.
  static const String moderateProduct = r'''
    mutation ModerateProduct(
      $id: uuid!,
      $isActive: Boolean!,
      $moderationStatus: String!,
      $moderatedBy: uuid!,
      $moderationNotes: String
    ) {
      update_products_by_pk(
        pk_columns: { id: $id },
        _set: {
          is_active: $isActive,
          moderation_status: $moderationStatus,
          moderated_by: $moderatedBy,
          moderation_notes: $moderationNotes
        }
      ) {
        id
        is_active
        moderation_status
        moderated_by
        moderated_at
      }
    }
  ''';
}
