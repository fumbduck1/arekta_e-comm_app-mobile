import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/graphql/queries/product_queries.dart';
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
  String? _searchTerm;
  String _sortField = 'created_at';
  String _sortOrder = 'desc';
  bool _isSearchVisible = false;

  @override
  void initState() {
    super.initState();
    _isSearchVisible = widget.showSearch;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _variables {
    final Map<String, dynamic> where = {};

    if (widget.categoryId != null) {
      where['category_id'] = {'_eq': widget.categoryId};
    }

    if (_searchTerm != null && _searchTerm!.isNotEmpty) {
      where['name'] = {'_ilike': '%$_searchTerm%'};
    }

    return {
      'limit': AppConstants.defaultPageSize,
      'offset': 0,
      'where': where,
      'orderBy': [
        {_sortField: _sortOrder},
      ],
    };
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
                  setState(() => _searchTerm = value);
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
                }
                _isSearchVisible = !_isSearchVisible;
              });
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
                      });
                    },
                    onPriceRangeChanged: (minPrice, maxPrice) {
                      // TODO: Implement price range filtering
                    },
                    onReset: () {
                      setState(() {
                        _sortField = 'created_at';
                        _sortOrder = 'desc';
                      });
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Query(
        options: QueryOptions(
          document: gql(ProductQueries.getProducts),
          variables: _variables,
          fetchPolicy: FetchPolicy.networkOnly,
        ),
        builder: (result, {fetchMore, refetch}) {
          if (result.isLoading && result.data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (result.hasException) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading products',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: refetch,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final products =
              (result.data?['products'] as List<dynamic>?)
                  ?.map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
                  .toList() ??
              [];

          final totalCount =
              result.data?['products_aggregate']?['aggregate']?['count']
                  as int? ??
              0;

          if (products.isEmpty) {
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
              // ── Result count ──────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Text(
                      '$totalCount product${totalCount != 1 ? 's' : ''} found',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Product Grid ──────────────────────────────
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return _ProductGridCard(product: product);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A grid card for product listing
class _ProductGridCard extends StatelessWidget {
  final ProductModel product;

  const _ProductGridCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        Navigator.of(
          context,
        ).pushNamed('/product-detail', arguments: product.id);
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ──────────────────────────────────────
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

            // ── Details ────────────────────────────────────
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
