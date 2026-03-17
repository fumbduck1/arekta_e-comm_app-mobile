/// GraphQL queries and mutations for Admin features
class AdminQueries {
  AdminQueries._();

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
