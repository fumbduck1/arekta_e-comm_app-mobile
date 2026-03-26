import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;

import '../../../core/graphql/queries/product_queries.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/product_model.dart';
import '../../../models/category_model.dart';
import '../../../models/carousel_coupon_model.dart';
import '../../cart/cart_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showSecondaryContent = false;

  @override
  void initState() {
    super.initState();
    // Defer secondary sections until after first frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _showSecondaryContent = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppConstants.appName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.of(
                context,
              ).pushNamed('/products', arguments: {'search': true});
            },
          ),
          Consumer<CartProvider>(
            builder: (context, cart, _) {
              return badges.Badge(
                showBadge: cart.itemCount > 0,
                badgeContent: Text(
                  '${cart.itemCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
                position: badges.BadgePosition.topEnd(top: 0, end: 3),
                child: IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined),
                  onPressed: () => Navigator.of(context).pushNamed('/cart'),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Refetch will be triggered by the Query widgets
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Carousels / Banners ────────────────────────
              _CarouselSection(),
              const SizedBox(height: 20),

              // ── Categories ─────────────────────────────────
              _SectionHeader(
                title: 'Categories',
                onSeeAll: () => Navigator.of(context).pushNamed('/products'),
              ),
              _CategoriesSection(),
              const SizedBox(height: 20),

              // ── Featured Products (deferred) ────────────────
              if (_showSecondaryContent) ...[
                _SectionHeader(
                  title: 'Featured Products',
                  onSeeAll: () => Navigator.of(context).pushNamed('/products'),
                ),
                _FeaturedProductsSection(),
                const SizedBox(height: 20),

                // ── New Arrivals (deferred) ─────────────────
                _SectionHeader(
                  title: 'New Arrivals',
                  onSeeAll: () => Navigator.of(
                    context,
                  ).pushNamed('/products', arguments: {'sort': 'newest'}),
                ),
                _NewArrivalsSection(),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Section Header
// ═══════════════════════════════════════════════════════════════
class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;

  const _SectionHeader({required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (onSeeAll != null)
            TextButton(onPressed: onSeeAll, child: const Text('See All')),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Carousel Banners
// ═══════════════════════════════════════════════════════════════
class _CarouselSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Query(
      options: QueryOptions(
        document: gql(ProductQueries.getCarousels),
        fetchPolicy: FetchPolicy.cacheAndNetwork,
      ),
      builder: (result, {fetchMore, refetch}) {
        if (result.isLoading && result.data == null) {
          return const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final carousels =
            (result.data?['carousels'] as List<dynamic>?)
                ?.map((e) => CarouselModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];

        if (carousels.isEmpty) {
          return Container(
            height: 180,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(
                'Welcome to Arekta!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }

        return CarouselSlider(
          options: CarouselOptions(
            height: 180,
            autoPlay: true,
            enlargeCenterPage: true,
            viewportFraction: 0.9,
            autoPlayInterval: const Duration(seconds: 4),
          ),
          items: carousels.map((carousel) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: carousel.imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                placeholder: (_, _) => Container(
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (_, _, _) => Container(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  child: const Icon(Icons.image_not_supported, size: 48),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Categories Horizontal List
// ═══════════════════════════════════════════════════════════════
class _CategoriesSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Query(
      options: QueryOptions(
        document: gql(ProductQueries.getCategories),
        fetchPolicy: FetchPolicy.cacheAndNetwork,
      ),
      builder: (result, {fetchMore, refetch}) {
        if (result.isLoading && result.data == null) {
          return const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (result.hasException) {
          debugPrint('Categories Query Error: ${result.exception}');
          return const SizedBox(
            height: 100,
            child: Center(child: Text('Failed to load categories')),
          );
        }

        final categories =
            (result.data?['categories'] as List<dynamic>?)
                ?.map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];

        if (categories.isEmpty) {
          return const SizedBox(
            height: 100,
            child: Center(child: Text('No categories')),
          );
        }

        return SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final category = categories[index];
              return GestureDetector(
                onTap: () {
                  Navigator.of(context).pushNamed(
                    '/products',
                    arguments: {'categoryId': category.id},
                  );
                },
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      backgroundImage: category.imageUrl != null
                          ? CachedNetworkImageProvider(category.imageUrl!)
                          : null,
                      child: category.imageUrl == null
                          ? Icon(
                              Icons.category,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 72,
                      child: Text(
                        category.name,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Featured Products Grid
// ═══════════════════════════════════════════════════════════════
class _FeaturedProductsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Query(
      options: QueryOptions(
        document: gql(ProductQueries.getProducts),
        variables: const {
          'limit': 6,
          'offset': 0,
          'orderBy': [
            {'created_at': 'desc'},
          ],
        },
        fetchPolicy: FetchPolicy.cacheAndNetwork,
      ),
      builder: (result, {fetchMore, refetch}) {
        if (result.isLoading && result.data == null) {
          return const SizedBox(
            height: 250,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (result.hasException) {
          debugPrint('Products Query Error: ${result.exception}');
          return const SizedBox(
            height: 200,
            child: Center(child: Text('Failed to load products')),
          );
        }

        final products =
            (result.data?['products'] as List<dynamic>?)
                ?.map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];

        if (products.isEmpty) {
          return const SizedBox(
            height: 200,
            child: Center(child: Text('No products yet')),
          );
        }

        return SizedBox(
          height: 250,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return _ProductCard(product: products[index]);
            },
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// New Arrivals — same query, different sort
// ═══════════════════════════════════════════════════════════════
class _NewArrivalsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Query(
      options: QueryOptions(
        document: gql(ProductQueries.getProducts),
        variables: const {
          'limit': 6,
          'offset': 0,
          'orderBy': [
            {'created_at': 'desc'},
          ],
        },
        fetchPolicy: FetchPolicy.cacheAndNetwork,
      ),
      builder: (result, {fetchMore, refetch}) {
        if (result.isLoading && result.data == null) {
          return const SizedBox(
            height: 250,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (result.hasException) {
          debugPrint('Products Query Error: ${result.exception}');
          return const SizedBox(
            height: 200,
            child: Center(child: Text('Failed to load products')),
          );
        }

        final products =
            (result.data?['products'] as List<dynamic>?)
                ?.map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];

        if (products.isEmpty) return const SizedBox.shrink();

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.7,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            return _ProductCard(product: products[index]);
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Reusable Product Card Widget
// ═══════════════════════════════════════════════════════════════
class _ProductCard extends StatelessWidget {
  final ProductModel product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          debugPrint(
            'Product card tapped: ${product.name} (ID: ${product.id})',
          );
          try {
            Navigator.of(context).pushNamed('/product', arguments: product.id);
          } catch (e) {
            debugPrint('Navigation error: $e');
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Navigation error: $e')));
          }
        },
        child: SizedBox(
          width: 160,
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Image ────────────────────────────────────
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: CachedNetworkImage(
                          imageUrl: product.primaryImage,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => Container(
                            color: Colors.grey[100],
                            child: const Center(
                              child: Icon(Icons.image, color: Colors.grey),
                            ),
                          ),
                          errorWidget: (_, _, _) => Container(
                            color: Colors.grey[100],
                            child: const Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      if (product.isOnSale)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '-${product.discountPercentage.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Details ──────────────────────────────────
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),

                        // Rating
                        if (product.avgRating != null)
                          Row(
                            children: [
                              Icon(
                                Icons.star,
                                size: 14,
                                color: Colors.amber[700],
                              ),
                              const SizedBox(width: 2),
                              Text(
                                product.avgRating!.toStringAsFixed(1),
                                style: theme.textTheme.bodySmall,
                              ),
                              Text(
                                ' (${product.reviewCount})',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 4),

                        // Price
                        Row(
                          children: [
                            Text(
                              '৳${product.price.toStringAsFixed(0)}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            if (product.isOnSale) ...[
                              const SizedBox(width: 6),
                              Text(
                                '৳${product.compareAtPrice!.toStringAsFixed(0)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  decoration: TextDecoration.lineThrough,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
