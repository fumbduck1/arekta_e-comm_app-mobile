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

  /// Fetch single product by ID with full details
  static const String getProductById = r'''
    query GetProductById($id: uuid!) {
      products_by_pk(id: $id) {
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
          shop_description: description
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
