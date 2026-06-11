import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/product_model.dart';
import '../widgets/filters_modal.dart';

class ProductListScreen extends StatefulWidget {
  final String? categoryId;
  final bool showSearch;

  const ProductListScreen({
    super.key,
    this.categoryId,
    this.showSearch = false,
  });

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  List<ProductModel> _products = [];
  bool _isLoading = true;
  int _totalCount = 0;
  int _offset = 0;
  String? _searchTerm;
  String _sortField = 'created_at';
  String _sortOrder = 'desc';
  bool _isSearchVisible = false;
  bool _hasMore = true;
  double? _selectedMinPrice;
  double? _selectedMaxPrice;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _isSearchVisible = widget.showSearch;
    _loadProducts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadProducts(loadMore: true);
    }
  }

  Future<void> _loadProducts({bool loadMore = false}) async {
    if (loadMore && !_hasMore) return;
    if (_isLoading) return;

    setState(() => _isLoading = !loadMore);

    try {
      if (loadMore) _offset += AppConstants.defaultPageSize;

      final supabase = Supabase.instance.client;

      if (!loadMore) {
        var countQuery = supabase
            .from('products')
            .select('id')
            .eq('is_active', true);

        final categoryId = widget.categoryId;
        if (categoryId != null) {
          countQuery = countQuery.eq('category_id', categoryId);
        }

        final searchTerm = _searchTerm;
        if (searchTerm != null && searchTerm.isNotEmpty) {
          countQuery = countQuery.ilike('name', '%$searchTerm%');
        }

        final minPrice = _selectedMinPrice;
        if (minPrice != null) {
          countQuery = countQuery.gte('price', minPrice);
        }
        final maxPrice = _selectedMaxPrice;
        if (maxPrice != null) {
          countQuery = countQuery.lte('price', maxPrice);
        }

        final countData = await countQuery;
        _totalCount = (countData as List).length;
      }

      dynamic query = supabase
          .from('products')
          .select('id, name, description, price, sale_price, stock, images, is_active, created_at, '
              'category:categories(id, name, slug), '
              'vendor:vendors(id, shop_name, logo_url)')
          .eq('is_active', true);

      final categoryId = widget.categoryId;
      if (categoryId != null) {
        query = query.eq('category_id', categoryId);
      }

      final searchTerm = _searchTerm;
      if (searchTerm != null && searchTerm.isNotEmpty) {
        query = query.ilike('name', '%$searchTerm%');
      }

      final minPrice = _selectedMinPrice;
      if (minPrice != null) {
        query = query.gte('price', minPrice);
      }
      final maxPrice = _selectedMaxPrice;
      if (maxPrice != null) {
        query = query.lte('price', maxPrice);
      }

      query = query
          .order(_sortField, ascending: _sortOrder == 'asc')
          .range(_offset, _offset + AppConstants.defaultPageSize - 1);

      final data = await query as List<dynamic>;

      if (!mounted) return;
      setState(() {
        if (loadMore) {
          _products.addAll(data
              .cast<Map<String, dynamic>>()
              .map((e) => ProductModel.fromJson(e)));
        } else {
          _products = data
              .cast<Map<String, dynamic>>()
              .map((e) => ProductModel.fromJson(e))
              .toList();
        }
        _hasMore = data.length >= AppConstants.defaultPageSize;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: _isSearchVisible
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search products...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: (value) {
                  setState(() {
                    _searchTerm = value;
                    _offset = 0;
                  });
                  _loadProducts();
                },
              )
            : const Text('Products'),
        actions: [
          IconButton(
            icon: Icon(_isSearchVisible ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearchVisible) {
                  _searchController.clear();
                  _searchTerm = null;
                  _offset = 0;
                }
                _isSearchVisible = !_isSearchVisible;
              });
              _loadProducts();
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (BuildContext context) {
                  return FiltersModal(
                    currentSortField: _sortField,
                    currentSortOrder: _sortOrder,
                    onSortChanged: (sortField, sortOrder) {
                      setState(() {
                        _sortField = sortField;
                        _sortOrder = sortOrder;
                        _offset = 0;
                      });
                      _loadProducts();
                    },
                    onPriceRangeChanged: (minPrice, maxPrice) {
                      setState(() {
                        _selectedMinPrice = minPrice;
                        _selectedMaxPrice = maxPrice;
                        _offset = 0;
                      });
                      _loadProducts();
                    },
                    onReset: () {
                      setState(() {
                        _sortField = 'created_at';
                        _sortOrder = 'desc';
                        _selectedMinPrice = null;
                        _selectedMaxPrice = null;
                        _offset = 0;
                      });
                      _loadProducts();
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading && _products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              _searchTerm != null
                  ? 'No products found for "$_searchTerm"'
                  : 'No products available',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                '$_totalCount product${_totalCount != 1 ? 's' : ''} found',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _products.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _products.length) {
                return const Center(child: CircularProgressIndicator());
              }
              final product = _products[index];
              return _ProductGridCard(product: product);
            },
          ),
        ),
      ],
    );
  }
}

class _ProductGridCard extends StatelessWidget {
  final ProductModel product;

  const _ProductGridCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed('/product', arguments: product.id);
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
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
                      child: const Icon(Icons.broken_image, color: Colors.grey),
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
                  if (!product.inStock)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black38,
                        child: const Center(
                          child: Text(
                            'Out of Stock',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
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
                    if (product.vendor != null)
                      Text(
                        product.vendor!.shopName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
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
    );
  }
}
