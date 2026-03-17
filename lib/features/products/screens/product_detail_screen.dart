import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../../../core/graphql/queries/product_queries.dart';
import '../../../models/product_model.dart';
import '../../../models/review_model.dart';

class ProductDetailScreen extends StatelessWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Query(
        options: QueryOptions(
          document: gql(ProductQueries.getProductById),
          variables: {'id': productId},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
        builder: (result, {fetchMore, refetch}) {
          if (result.isLoading && result.data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = result.data?['products_by_pk'];
          if (data == null) {
            return const Center(child: Text('Product not found'));
          }

          final product = ProductModel.fromJson(data as Map<String, dynamic>);
          final reviews =
              (data['reviews'] as List<dynamic>?)
                  ?.map((e) => ReviewModel.fromJson(e as Map<String, dynamic>))
                  .toList() ??
              [];

          return _ProductDetailContent(product: product, reviews: reviews);
        },
      ),
    );
  }
}

class _ProductDetailContent extends StatefulWidget {
  final ProductModel product;
  final List<ReviewModel> reviews;

  const _ProductDetailContent({required this.product, required this.reviews});

  @override
  State<_ProductDetailContent> createState() => _ProductDetailContentState();
}

class _ProductDetailContentState extends State<_ProductDetailContent> {
  int _selectedImageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = widget.product;

    return CustomScrollView(
      slivers: [
        // ── Image Gallery AppBar ─────────────────────────────
        SliverAppBar(
          expandedHeight: 350,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              children: [
                // Main image
                PageView.builder(
                  itemCount: product.images.length.clamp(1, 999),
                  onPageChanged: (index) {
                    setState(() => _selectedImageIndex = index);
                  },
                  itemBuilder: (context, index) {
                    final imageUrl = product.images.isNotEmpty
                        ? product.images[index]
                        : product.primaryImage;
                    return CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        color: Colors.grey[100],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (_, _, _) => Container(
                        color: Colors.grey[100],
                        child: const Icon(Icons.broken_image, size: 64),
                      ),
                    );
                  },
                ),

                // Image indicators
                if (product.images.length > 1)
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(product.images.length, (i) {
                        return Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == _selectedImageIndex
                                ? theme.colorScheme.primary
                                : Colors.white54,
                          ),
                        );
                      }),
                    ),
                  ),

                // Sale badge
                if (product.isOnSale)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 56,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '-${product.discountPercentage.toStringAsFixed(0)}% OFF',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // ── Product Info ─────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                Text(
                  product.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Vendor
                if (product.vendor != null)
                  GestureDetector(
                    onTap: () {
                      // Navigate to vendor profile
                    },
                    child: Row(
                      children: [
                        const Icon(
                          Icons.store_outlined,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          product.vendor!.shopName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),

                // Price
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '৳${product.price.toStringAsFixed(0)}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    if (product.isOnSale) ...[
                      const SizedBox(width: 8),
                      Text(
                        '৳${product.compareAtPrice!.toStringAsFixed(0)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          decoration: TextDecoration.lineThrough,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // Rating summary
                if (product.avgRating != null)
                  Row(
                    children: [
                      RatingBarIndicator(
                        rating: product.avgRating!,
                        itemBuilder: (_, _) =>
                            const Icon(Icons.star, color: Colors.amber),
                        itemCount: 5,
                        itemSize: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${product.avgRating!.toStringAsFixed(1)} (${product.reviewCount} reviews)',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                const SizedBox(height: 8),

                // Stock status
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: product.inStock
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    product.inStock
                        ? 'In Stock (${product.stockQty} available)'
                        : 'Out of Stock',
                    style: TextStyle(
                      color: product.inStock ? Colors.green[700] : Colors.red,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Description
                Text(
                  'Description',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  product.description ?? 'No description available.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),

                // ── Reviews Section ──────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Reviews (${widget.reviews.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // Navigate to write review or see all reviews
                      },
                      child: const Text('Write a Review'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (widget.reviews.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No reviews yet. Be the first to review!'),
                  )
                else
                  ...widget.reviews.map(
                    (review) => _ReviewCard(review: review),
                  ),
                const SizedBox(height: 80), // Space for bottom bar
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Review card widget
class _ReviewCard extends StatelessWidget {
  final ReviewModel review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: review.user?.avatarUrl != null
                        ? CachedNetworkImageProvider(review.user!.avatarUrl!)
                        : null,
                    child: review.user?.avatarUrl == null
                        ? Text(
                            (review.user?.name ?? '?')[0].toUpperCase(),
                            style: const TextStyle(fontSize: 14),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          review.user?.name ?? 'Anonymous',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        RatingBarIndicator(
                          rating: review.rating.toDouble(),
                          itemBuilder: (_, _) =>
                              const Icon(Icons.star, color: Colors.amber),
                          itemCount: 5,
                          itemSize: 14,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (review.comment != null && review.comment!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(review.comment!, style: theme.textTheme.bodyMedium),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
