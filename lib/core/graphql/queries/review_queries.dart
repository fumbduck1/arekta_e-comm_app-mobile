/// GraphQL query and mutation strings for Reviews
class ReviewQueries {
  ReviewQueries._();

  /// Get reviews for a product
  static const String getProductReviews = r'''
    query GetProductReviews($productId: uuid!, $limit: Int!, $offset: Int!) {
      reviews(
        where: { product_id: { _eq: $productId } },
        order_by: { created_at: desc },
        limit: $limit,
        offset: $offset
      ) {
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
      reviews_aggregate(where: { product_id: { _eq: $productId } }) {
        aggregate {
          avg { rating }
          count
        }
      }
    }
  ''';
}

class ReviewMutations {
  ReviewMutations._();

  /// Create a review
  static const String createReview = r'''
    mutation CreateReview(
      $productId: uuid!,
      $rating: Int!,
      $comment: String
    ) {
      insert_reviews_one(object: {
        product_id: $productId,
        rating: $rating,
        comment: $comment
      }) {
        id
        rating
        comment
        created_at
      }
    }
  ''';
}
