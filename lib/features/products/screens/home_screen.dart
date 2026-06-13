import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;
import 'package:supabase_flutter/supabase_flutter.dart';

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
          await _refreshAll();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CarouselSection(key: _carouselKey),
              const SizedBox(height: 20),
              _SectionHeader(
                title: 'Categories',
                onSeeAll: () => Navigator.of(context).pushNamed('/products'),
              ),
              _CategoriesSection(key: _categoriesKey),
              const SizedBox(height: 20),
              if (_showSecondaryContent) ...[
                _SectionHeader(
                  title: 'Featured Products',
                  onSeeAll: () => Navigator.of(context).pushNamed('/products'),
                ),
                _FeaturedProductsSection(key: _featuredKey),
                const SizedBox(height: 20),
                _SectionHeader(
                  title: 'New Arrivals',
                  onSeeAll: () => Navigator.of(
                    context,
                  ).pushNamed('/products', arguments: {'sort': 'newest'}),
                ),
                _NewArrivalsSection(key: _newArrivalsKey),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  final _carouselKey = GlobalKey<_CarouselSectionState>();
  final _categoriesKey = GlobalKey<_CategoriesSectionState>();
  final _featuredKey = GlobalKey<_FeaturedProductsSectionState>();
  final _newArrivalsKey = GlobalKey<_NewArrivalsSectionState>();

  Future<void> _refreshAll() async {
    await Future.wait([
      _carouselKey.currentState?.load() ?? Future.value(),
      _categoriesKey.currentState?.load() ?? Future.value(),
      _featuredKey.currentState?.load() ?? Future.value(),
      _newArrivalsKey.currentState?.load() ?? Future.value(),
    ]);
  }
}

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

class _CarouselSection extends StatefulWidget {
  const _CarouselSection({super.key});

  @override
  State<_CarouselSection> createState() => _CarouselSectionState();
}

class _CarouselSectionState extends State<_CarouselSection> {
  List<CarouselModel> _carousels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('carousels')
          .select('id, title, image_url, link_type, link_value, sort_order')
          .eq('is_active', true)
          .order('sort_order');
      if (!mounted) return;
      setState(() {
        _carousels = (data as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map((e) => CarouselModel.fromJson(e))
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_carousels.isEmpty) {
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
      items: _carousels.map((carousel) {
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
  }
}

class _CategoriesSection extends StatefulWidget {
  const _CategoriesSection({super.key});

  @override
  State<_CategoriesSection> createState() => _CategoriesSectionState();
}

class _CategoriesSectionState extends State<_CategoriesSection> {
  List<CategoryModel> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('categories')
          .select('id, name, slug, image_url, parent_id')
          .order('name');
      if (!mounted) return;
      setState(() {
        _categories = (data as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map((e) => CategoryModel.fromJson(e))
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_categories.isEmpty) {
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
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final category = _categories[index];
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
  }
}

class _FeaturedProductsSection extends StatefulWidget {
  const _FeaturedProductsSection({super.key});

  @override
  State<_FeaturedProductsSection> createState() =>
      _FeaturedProductsSectionState();
}

class _FeaturedProductsSectionState extends State<_FeaturedProductsSection> {
  List<ProductModel> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('vw_top_products_by_sales')
          .select(
            'id, name, description, price, sale_price, stock, images, is_active, created_at, '
            'category, vendor, total_sold',
          )
          .limit(6);
      if (!mounted) return;
      setState(() {
        _products = (data as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map((e) => ProductModel.fromJson(e))
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 250,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_products.isEmpty) {
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
        itemCount: _products.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return _ProductCard(product: _products[index]);
        },
      ),
    );
  }
}

class _NewArrivalsSection extends StatefulWidget {
  const _NewArrivalsSection({super.key});

  @override
  State<_NewArrivalsSection> createState() => _NewArrivalsSectionState();
}

class _NewArrivalsSectionState extends State<_NewArrivalsSection> {
  List<ProductModel> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('vw_active_products_catalog')
          .select('id,name,description,price,sale_price,stock,images,created_at,'
              'vendor_id,shop_name,category_id,category_name,avg_rating,review_count,'
              'discount_percentage,in_stock,stock_status')
          .order('created_at', ascending: false)
          .limit(6);
      if (!mounted) return;
      setState(() {
        _products = (data as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map((e) => ProductModel.fromJson(e))
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 250,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_products.isEmpty) return const SizedBox.shrink();

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
      itemCount: _products.length,
      itemBuilder: (context, index) {
        return _ProductCard(product: _products[index]);
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductModel product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed('/product', arguments: product.id);
      },
      child: SizedBox(
        width: 160,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
    );
  }
}
