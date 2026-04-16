/// GraphQL query and mutation strings for Products
class ProductQueries {
  ProductQueries._();

  /// Fetch paginated products with optional filters
  static const String getProducts = r'''
    query GetProducts(
      $limit: Int!,
      $offset: Int!,
      $orderBy: [products_order_by!],
      $where: products_bool_exp = {}
    ) {
      products(
        limit: $limit,
        offset: $offset,
        where: {
          _and: [
            { is_active: { _eq: true } },
            $where
          ]
        },
        order_by: $orderBy
      ) {
        id
        name
        description
        price
        compare_at_price: sale_price
        stock_qty: stock
        images
        is_active
        created_at
        category {
          id
          name
          slug
        }
        vendor {
          id
          shop_name
          logo_url
        }
        reviews_aggregate {
          aggregate {
            avg { rating }
            count
          }
        }
      }
      products_aggregate(
        where: {
          _and: [
            { is_active: { _eq: true } },
            $where
          ]
        }
      ) {
        aggregate {
          count
        }
      }
    }
  ''';

  /// OPTIMIZED: Fetch active products catalog using pre-aggregated view
  /// Replaces multiple JOINs with single view query
  /// Use this for product listings with ratings and discounts
  static const String getActiveProductsCatalog = r'''
    query GetActiveProductsCatalog(
      $limit: Int,
      $offset: Int,
      $orderBy: [vw_active_products_catalog_order_by!]
    ) {
      vw_active_products_catalog(
        limit: $limit,
        offset: $offset,
        order_by: $orderBy
      ) {
        id
        name
        description
        price
        sale_price
        stock
        images
        created_at
        vendor_id
        shop_name
        vendor_approved
        category_id
        category_name
        avg_rating
        review_count
        discount_percentage
        in_stock
        stock_status
      }
      vw_active_products_catalog_aggregate {
        aggregate {
          count
        }
      }
    }
  ''';

  /// Permission-safe single product detail from catalog view.
  /// Use this when direct `products` table access is restricted by Hasura RBAC.
  static const String getActiveProductDetailById = r'''
    query GetActiveProductDetailById($id: uuid!) {
      vw_active_products_catalog(
        where: { id: { _eq: $id } },
        limit: 1
      ) {
        id
        name
        description
        price
        sale_price
        stock
        images
        created_at
        vendor_id
        shop_name
        category_id
        category_name
        avg_rating
        review_count
        in_stock
      }
    }
  ''';

  /// OPTIMIZED: Get trending products using view
  static const String getTrendingProducts = r'''
    query GetTrendingProducts($limit: Int) {
      vw_top_products_by_sales(
        limit: $limit,
        order_by: { units_sold: desc }
      ) {
        id
        name
        price
        sale_price
        images
        vendor_id
        shop_name
        units_sold
        total_revenue
        avg_rating
        review_count
      }
    }
  ''';

  /// Fetch single product by ID with full details
  static const String getProductById = r'''
    query GetProductById($id: uuid!) {
      products(where: { id: { _eq: $id } }, limit: 1) {
        id
        name
        description
        price
        compare_at_price: sale_price
        stock_qty: stock
        images
        is_active
        created_at
        category {
          id
          name
          slug
        }
        vendor {
          id
          shop_name
          description
          logo_url
        }
        reviews(order_by: { created_at: desc }, limit: 10) {
          id
          rating
          comment
          created_at
          user {
            id
            name
            avatar_url
          }
        }
        reviews_aggregate {
          aggregate {
            avg { rating }
            count
          }
        }
      }
    }
  ''';

  /// Fetch all categories
  static const String getCategories = r'''
    query GetCategories {
      categories(order_by: { name: asc }) {
        id
        name
        slug
        image_url
        parent_id
      }
    }
  ''';

  /// Fetch active carousels/banners
  static const String getCarousels = r'''
    query GetCarousels {
      carousels(
        where: { is_active: { _eq: true } },
        order_by: { sort_order: asc }
      ) {
        id
        title
        image_url
        link_type
        link_value
        sort_order
      }
    }
  ''';
}

/// GraphQL mutations for Products (vendor use)
class ProductMutations {
  ProductMutations._();

  static const String createProduct = r'''
    mutation CreateProduct(
      $vendorId: uuid!,
      $name: String!,
      $description: String!,
      $price: numeric!,
      $compareAtPrice: numeric,
      $categoryId: uuid!,
      $stockQty: Int!,
      $images: jsonb!
    ) {
      insert_products_one(object: {
        vendor_id: $vendorId,
        name: $name,
        description: $description,
        price: $price,
        sale_price: $compareAtPrice,
        category_id: $categoryId,
        stock: $stockQty,
        images: $images
      }) {
        id
        name
      }
    }
  ''';

  static const String updateProduct = r'''
    mutation UpdateProduct(
      $id: uuid!,
      $name: String,
      $description: String,
      $price: numeric,
      $compareAtPrice: numeric,
      $categoryId: uuid,
      $stockQty: Int,
      $images: jsonb,
      $isActive: Boolean
    ) {
      update_products_by_pk(
        pk_columns: { id: $id },
        _set: {
          name: $name,
          description: $description,
          price: $price,
          sale_price: $compareAtPrice,
          category_id: $categoryId,
          stock: $stockQty,
          images: $images,
          is_active: $isActive
        }
      ) {
        id
        name
      }
    }
  ''';

  static const String deleteProduct = r'''
    mutation DeleteProduct($id: uuid!) {
      update_products_by_pk(
        pk_columns: { id: $id },
        _set: { is_active: false }
      ) {
        id
      }
    }
  ''';
}
