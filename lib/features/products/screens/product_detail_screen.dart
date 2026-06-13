import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/product_model.dart';
import '../../../models/review_model.dart';
import '../../auth/auth_provider.dart';
import '../../cart/cart_provider.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  ProductModel? _product;
  List<ReviewModel> _reviews = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final supabase = Supabase.instance.client;

      final productData = await supabase
          .from('products')
          .select(
            'id, name, description, price, sale_price, stock, images, is_active, created_at, '
            'category:categories(id, name, slug), '
            'vendor:vendors(id, shop_name, logo_url)',
          )
          .eq('id', widget.productId)
          .single();

      final reviewsAgg = await supabase
          .from('reviews')
          .select('rating')
          .eq('product_id', widget.productId);

      final avgRating = (reviewsAgg as List<dynamic>).isEmpty
          ? null
          : reviewsAgg
                  .cast<Map<String, dynamic>>()
                  .map((r) => (r['rating'] as num).toDouble())
                  .reduce((a, b) => a + b) /
              reviewsAgg.length;

      final reviewsData = await supabase
          .from('reviews')
          .select('id, rating, comment, created_at, user:users(id, name, avatar_url)')
          .eq('product_id', widget.productId)
          .order('created_at', ascending: false)
          .limit(10);

      if (!mounted) return;
      setState(() {
        productData['reviews_aggregate'] = {
          'aggregate': {
            'avg': {'rating': avgRating},
            'count': reviewsAgg.length,
          },
        };
        _product = ProductModel.fromJson(productData);
        _reviews = (reviewsData as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map((r) => ReviewModel.fromJson(r))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load product details: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load product';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return _ErrorScreen(
        error: _error!,
        onRetry: _loadData,
      );
    }

    if (_product == null) {
      return const _EmptyProductScreen();
    }

    return _ProductDetailContent(
      product: _product!,
      reviews: _reviews,
      onReviewAdded: _loadData,
    );
  }
}

class _ProductDetailContent extends StatefulWidget {
  final ProductModel product;
  final List<ReviewModel> reviews;
  final VoidCallback onReviewAdded;

  const _ProductDetailContent({
    required this.product,
    required this.reviews,
    required this.onReviewAdded,
  });

  @override
  State<_ProductDetailContent> createState() => _ProductDetailContentState();
}

class _ProductDetailContentState extends State<_ProductDetailContent> {
  int _selectedImageIndex = 0;
  int _quantity = 1;
  bool _addingToCart = false;

  void _showReviewDialog() {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      Navigator.of(context).pushNamed('/login');
      return;
    }

    int rating = 5;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Write a Review'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RatingBar.builder(
                initialRating: rating.toDouble(),
                minRating: 1,
                direction: Axis.horizontal,
                itemCount: 5,
                itemSize: 32,
                itemBuilder: (_, _) => const Icon(Icons.star, color: Colors.amber),
                onRatingUpdate: (val) => setDialogState(() => rating = val.toInt()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  hintText: 'Share your experience...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await Supabase.instance.client.from('reviews').insert({
                    'product_id': widget.product.id,
                    'user_id': user.id,
                    'rating': rating,
                    'comment': commentController.text.trim().isEmpty
                        ? null
                        : commentController.text.trim(),
                  });
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  widget.onReviewAdded();
                } catch (e) {
                  debugPrint('Failed to submit review: $e');
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Failed to submit review')),
                    );
                  }
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = widget.product;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 350,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        onPressed: _showReviewDialog,
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
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
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
                                    debugPrint('Failed to add to cart: $e');
                                    if (mounted) {
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('Failed to add to cart'),
                                          backgroundColor: Colors.red,
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

class _ErrorScreen extends StatelessWidget {
  final String error;
  final VoidCallback? onRetry;

  const _ErrorScreen({required this.error, this.onRetry});

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
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 24),
              Text(
                'Unable to Load Product',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                error,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (onRetry != null)
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
}

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
