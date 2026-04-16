import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';

import '../../../models/product_model.dart';
import '../../../models/review_model.dart';
import '../../../core/graphql/queries/product_queries.dart';
import '../../auth/auth_provider.dart';
import '../../cart/cart_provider.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _hasRetriedWithPublicRole = false;
  bool _forcePublicRoleForRead = false;

  bool _isPermissionOrAuthException(OperationException? exception) {
    if (exception == null) return false;

    final messages = <String>[
      ...exception.graphqlErrors.map((e) => e.message),
      exception.linkException?.toString() ?? '',
      exception.toString(),
    ].join(' ').toLowerCase();

    return messages.contains('permission') ||
        messages.contains('unauthorized') ||
        messages.contains('forbidden') ||
        messages.contains('authentication') ||
        messages.contains('jwt') ||
        messages.contains('access denied') ||
        messages.contains('not allowed');
  }

  void _retryWithPublicRoleFallback() {
    if (_hasRetriedWithPublicRole) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasRetriedWithPublicRole) return;
      setState(() {
        _hasRetriedWithPublicRole = true;
        _forcePublicRoleForRead = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final roleContext = _forcePublicRoleForRead
        ? Context().withEntry(
            const HttpLinkHeaders(headers: {'x-hasura-role': 'public'}),
          )
        : const Context();

    return Scaffold(
      body: Query(
        options: QueryOptions(
          document: gql(ProductQueries.getProducts),
          variables: {
            'limit': 1,
            'offset': 0,
            'orderBy': [
              {'created_at': 'desc'},
            ],
            'where': {
              'id': {'_eq': widget.productId},
            },
          },
          fetchPolicy: FetchPolicy.networkOnly,
          context: roleContext,
        ),
        builder: (result, {fetchMore, refetch}) {
          // Loading state
          if (result.isLoading && result.data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error handling
          if (result.hasException) {
            if (!_forcePublicRoleForRead &&
                _isPermissionOrAuthException(result.exception)) {
              _retryWithPublicRoleFallback();
              return const Center(child: CircularProgressIndicator());
            }

            return _ErrorScreen(exception: result.exception, onRetry: refetch);
          }

          // Empty result
          final products = result.data?['products'] as List<dynamic>?;
          if (products == null || products.isEmpty) {
            return const _EmptyProductScreen();
          }

          final productData = products.first as Map<String, dynamic>;

          // Parse product data
          try {
            final product = ProductModel.fromJson(productData);
            const reviews = <ReviewModel>[];

            return _ProductDetailContent(product: product, reviews: reviews);
          } catch (e) {
            debugPrint('[ProductDetail] Error parsing product: $e');
            return _ParseErrorScreen(error: e.toString());
          }
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
  int _quantity = 1;
  bool _addingToCart = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = widget.product;

    return Scaffold(
      body: CustomScrollView(
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
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
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
                  const SizedBox(height: 120), // Space for bottom action bar
                ],
              ),
            ),
          ),
        ],
      ),
      // ── Bottom Action Bar ──────────────────────────────────────
      bottomNavigationBar: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final isAuthenticated = auth.isAuthenticated;
          final canAddToCart = isAuthenticated && product.inStock;

          return Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 12,
              top: 12,
            ),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Quantity selector (only for authenticated users)
                if (isAuthenticated && product.inStock)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Quantity:'),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _quantity > 1
                                  ? () => setState(() => _quantity--)
                                  : null,
                              icon: const Icon(Icons.remove),
                              iconSize: 20,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                            SizedBox(
                              width: 40,
                              child: Center(
                                child: Text(
                                  _quantity.toString(),
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _quantity < product.stockQty
                                  ? () => setState(() => _quantity++)
                                  : null,
                              icon: const Icon(Icons.add),
                              iconSize: 20,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                if (isAuthenticated && product.inStock)
                  const SizedBox(height: 12),
                // Action button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: isAuthenticated
                      ? ElevatedButton.icon(
                          onPressed: canAddToCart && !_addingToCart
                              ? () async {
                                  setState(() => _addingToCart = true);
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  try {
                                    final cartProvider = context
                                        .read<CartProvider>();
                                    await cartProvider.addToCart(
                                      product.id,
                                      quantity: _quantity,
                                    );
                                    if (mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Added $_quantity item(s) to cart',
                                          ),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                      setState(() => _quantity = 1);
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text('Error: $e'),
                                          backgroundColor:
                                              theme.colorScheme.error,
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() => _addingToCart = false);
                                    }
                                  }
                                }
                              : null,
                          icon: _addingToCart
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.shopping_cart_outlined),
                          label: Text(
                            product.inStock ? 'Add to Cart' : 'Out of Stock',
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushNamed('/login');
                          },
                          icon: const Icon(Icons.login),
                          label: const Text('Sign in to Add to Cart'),
                        ),
                ),
              ],
            ),
          );
        },
      ),
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

/// Error screen for GraphQL/network errors
class _ErrorScreen extends StatelessWidget {
  final OperationException? exception;
  final VoidCallback? onRetry;

  const _ErrorScreen({this.exception, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorMessage = _parseErrorMessage(exception);
    final isAuthError =
        errorMessage.contains('authentication') ||
        errorMessage.contains('unauthorized');

    return Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isAuthError ? Icons.lock : Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 24),
              Text(
                isAuthError
                    ? 'Authentication Required'
                    : 'Unable to Load Product',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                errorMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (isAuthError)
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pushNamed('/login'),
                  icon: const Icon(Icons.login),
                  label: const Text('Sign In'),
                )
              else if (onRetry != null)
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _parseErrorMessage(OperationException? exception) {
    if (exception == null) return 'An unknown error occurred.';

    // Check for GraphQL errors
    if (exception.graphqlErrors.isNotEmpty) {
      final error = exception.graphqlErrors.first;
      final message = error.message.toLowerCase();

      if (message.contains('invalid input syntax')) {
        return 'There\'s a permission issue. Please try again or contact support.';
      }
      if (message.contains('authentication') ||
          message.contains('unauthorized') ||
          message.contains('jwt')) {
        return 'Your session has expired. Please sign in again.';
      }
      if (message.contains('not found')) {
        return 'This product is no longer available.';
      }

      return error.message;
    }

    // Check for network errors
    if (exception.linkException != null) {
      return 'Network connection error. Check your internet and try again.';
    }

    return 'An error occurred while loading the product.';
  }
}

/// Empty product screen
class _EmptyProductScreen extends StatelessWidget {
  const _EmptyProductScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Product Not Found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shopping_bag_outlined,
                size: 64,
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 24),
              Text(
                'Product Not Found',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'This product is no longer available or may have been removed.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Products'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Parse error screen
class _ParseErrorScreen extends StatelessWidget {
  final String error;

  const _ParseErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_outlined, size: 64, color: Colors.orange[600]),
              const SizedBox(height: 24),
              Text(
                'Failed to Parse Product',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'The product data format is invalid. This is usually a temporary issue.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
