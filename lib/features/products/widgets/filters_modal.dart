import 'package:flutter/material.dart';

/// Modal widget for filtering and sorting products
class FiltersModal extends StatefulWidget {
  final String currentSortField;
  final String currentSortOrder;
  final double? minPrice;
  final double? maxPrice;
  final void Function(String sortField, String sortOrder) onSortChanged;
  final void Function(double? minPrice, double? maxPrice) onPriceRangeChanged;
  final VoidCallback onReset;

  const FiltersModal({
    super.key,
    required this.currentSortField,
    required this.currentSortOrder,
    this.minPrice,
    this.maxPrice,
    required this.onSortChanged,
    required this.onPriceRangeChanged,
    required this.onReset,
  });

  @override
  State<FiltersModal> createState() => _FiltersModalState();
}

class _FiltersModalState extends State<FiltersModal> {
  late String _selectedSort;
  late double _minPrice;
  late double _maxPrice;

  @override
  void initState() {
    super.initState();
    _selectedSort = _getSortLabel(
      widget.currentSortField,
      widget.currentSortOrder,
    );
    _minPrice = widget.minPrice ?? 0;
    _maxPrice = widget.maxPrice ?? 10000;
  }

  String _getSortLabel(String field, String order) {
    if (field == 'created_at' && order == 'desc') return 'newest';
    if (field == 'price' && order == 'asc') return 'price_low';
    if (field == 'price' && order == 'desc') return 'price_high';
    if (field == 'name' && order == 'asc') return 'name';
    return 'newest';
  }

  void _applySortChanges(String sortValue) {
    switch (sortValue) {
      case 'newest':
        widget.onSortChanged('created_at', 'desc');
        break;
      case 'price_low':
        widget.onSortChanged('price', 'asc');
        break;
      case 'price_high':
        widget.onSortChanged('price', 'desc');
        break;
      case 'name':
        widget.onSortChanged('name', 'asc');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sort & Filter',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedSort = 'newest';
                          _minPrice = 0;
                          _maxPrice = 10000;
                        });
                        widget.onReset();
                      },
                      child: const Text(
                        'Reset',
                        style: TextStyle(color: Color(0xFF6C63FF)),
                      ),
                    ),
                  ],
                ),
              ),

              Divider(height: 1, color: Colors.grey[200]),

              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    // Sort Section
                    _buildSectionHeader('Sort By'),
                    const SizedBox(height: 12),
                    _buildSortOption('newest', 'Newest First'),
                    _buildSortOption('price_low', 'Price: Low to High'),
                    _buildSortOption('price_high', 'Price: High to Low'),
                    _buildSortOption('name', 'Name: A to Z'),

                    const SizedBox(height: 24),

                    // Price Range Section
                    _buildSectionHeader('Price Range'),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '\$${_minPrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '\$${_maxPrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    RangeSlider(
                      values: RangeValues(_minPrice, _maxPrice),
                      min: 0,
                      max: 10000,
                      divisions: 100,
                      labels: RangeLabels(
                        '\$${_minPrice.toStringAsFixed(0)}',
                        '\$${_maxPrice.toStringAsFixed(0)}',
                      ),
                      activeColor: const Color(0xFF6C63FF),
                      inactiveColor: Colors.grey[200],
                      onChanged: (values) {
                        setState(() {
                          _minPrice = values.start;
                          _maxPrice = values.end;
                        });
                      },
                    ),
                  ],
                ),
              ),

              Divider(height: 1, color: Colors.grey[200]),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _applySortChanges(_selectedSort);
                          widget.onPriceRangeChanged(_minPrice, _maxPrice);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Apply Filters'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildSortOption(String value, String label) {
    final isSelected = _selectedSort == value;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedSort = value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6C63FF).withValues(alpha: 0.1)
              : Colors.transparent,
          border: Border.all(
            color: isSelected ? const Color(0xFF6C63FF) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF6C63FF)
                      : Colors.grey[300]!,
                  width: isSelected ? 2 : 1,
                ),
                color: isSelected
                    ? const Color(0xFF6C63FF)
                    : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                color: isSelected ? const Color(0xFF6C63FF) : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
