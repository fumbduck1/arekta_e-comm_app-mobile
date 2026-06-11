import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/carousel_coupon_model.dart';
import '../../cart/cart_provider.dart';
import '../widgets/checkout_details_modal.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _couponController = TextEditingController();

  String _paymentMethod = 'cod';
  bool _isPlacingOrder = false;
  CouponModel? _appliedCoupon;
  bool _isValidatingCoupon = false;

  String _savedAddress = '';
  String _savedCity = '';
  String _savedPhone = '';
  String _savedPaymentMethod = 'cod';

  @override
  void initState() {
    super.initState();
    _loadSavedState();
  }

  void _loadSavedState() {
    _addressController.text = _savedAddress;
    _cityController.text = _savedCity;
    _phoneController.text = _savedPhone;
    _paymentMethod = _savedPaymentMethod;
  }

  void _saveState() {
    _savedAddress = _addressController.text;
    _savedCity = _cityController.text;
    _savedPhone = _phoneController.text;
    _savedPaymentMethod = _paymentMethod;
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;

    _saveState();

    setState(() => _isPlacingOrder = true);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      final shippingAddress =
          '${_addressController.text}, ${_cityController.text}\nPhone: ${_phoneController.text}';

      await supabase.rpc('create_order_from_cart', params: {
        'p_user_id': userId,
        'p_shipping_address': shippingAddress,
        'p_payment_method': _paymentMethod,
        if (_appliedCoupon != null) 'p_coupon_code': _appliedCoupon!.code,
      });

      if (!mounted) return;
      final cart = context.read<CartProvider>();
      await cart.clearCart();

      _savedAddress = '';
      _savedCity = '';
      _savedPhone = '';
      _savedPaymentMethod = 'cod';

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order placed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to place order: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  double _calculateDiscount(double subtotal) {
    if (_appliedCoupon == null) return 0;
    if (_appliedCoupon!.isPercentage) {
      return subtotal * _appliedCoupon!.discountValue / 100;
    }
    return _appliedCoupon!.discountValue;
  }

  Future<void> _validateCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isValidatingCoupon = true);

    try {
      final data = await Supabase.instance.client
          .from('coupons')
          .select('id, code, discount_type, discount_value, min_order, max_uses, used_count, vendor_id, expires_at, is_active')
          .eq('code', code)
          .eq('is_active', true)
          .maybeSingle();

      if (!mounted) return;

      if (data == null) {
        _showCouponError('Invalid coupon code');
        return;
      }

      final coupon = CouponModel.fromJson(data);

      if (!coupon.isValid) {
        _showCouponError(
          coupon.isExpired
              ? 'Coupon has expired'
              : 'Coupon usage limit reached',
        );
        return;
      }

      final subtotal = context.read<CartProvider>().subtotal;
      if (coupon.minOrder != null && subtotal < coupon.minOrder!) {
        _showCouponError(
          'Minimum order ৳${coupon.minOrder!.toStringAsFixed(0)} required',
        );
        return;
      }

      setState(() => _appliedCoupon = coupon);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Coupon applied! ${coupon.isPercentage ? '${coupon.discountValue.toStringAsFixed(0)}% off' : '৳${coupon.discountValue.toStringAsFixed(0)} off'}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showCouponError('Failed to validate coupon');
    } finally {
      if (mounted) setState(() => _isValidatingCoupon = false);
    }
  }

  void _showCouponError(String message) {
    setState(() => _appliedCoupon = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showCheckoutDetails(CartProvider cart) {
    final discount = _appliedCoupon != null
        ? _calculateDiscount(cart.subtotal)
        : 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => CheckoutDetailsModal(
        subtotal: cart.subtotal,
        shippingCost: 0.0,
        taxCost: 0.0,
        discountAmount: discount > 0 ? discount : null,
        couponCode: _appliedCoupon?.code,
        onApplyCoupon: (code) {
          Navigator.pop(context);
          _couponController.text = code;
          _validateCoupon();
        },
        onRemoveCoupon: () {
          setState(() => _appliedCoupon = null);
          Navigator.pop(context);
        },
        onProceedCheckout: () {
          Navigator.pop(context);
          _placeOrder();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.currency(symbol: '৳', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Consumer<CartProvider>(
        builder: (context, cart, _) {
          if (cart.cart == null || cart.cart!.items.isEmpty) {
            return const Center(child: Text('Your cart is empty'));
          }

          final cartModel = cart.cart!;

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order Summary',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.receipt_long, size: 16),
                      label: const Text('View All'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () => _showCheckoutDetails(cart),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        ...cartModel.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item.product.name} × ${item.quantity}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  currency.format(item.lineTotal),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total (${cartModel.totalItems} items)',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              currency.format(cartModel.subtotal),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Shipping Address',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    hintText: 'Street address, house number',
                    prefixIcon: Icon(Icons.home_outlined),
                  ),
                  maxLines: 2,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Address is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(
                    hintText: 'City',
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'City is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    hintText: 'Phone number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Phone number is required'
                      : null,
                ),

                const SizedBox(height: 24),

                Text(
                  'Coupon Code (Optional)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _couponController,
                        decoration: const InputDecoration(
                          hintText: 'Enter coupon code',
                          prefixIcon: Icon(Icons.local_offer_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isValidatingCoupon ? null : _validateCoupon,
                      child: _isValidatingCoupon
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Apply'),
                    ),
                  ],
                ),
                if (_appliedCoupon != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Coupon "${_appliedCoupon!.code}" applied — '
                            '${_appliedCoupon!.isPercentage ? '${_appliedCoupon!.discountValue.toStringAsFixed(0)}% off' : '৳${_appliedCoupon!.discountValue.toStringAsFixed(0)} off'}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () =>
                              setState(() => _appliedCoupon = null),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                Text(
                  'Payment Method',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: RadioGroup<String>(
                    groupValue: _paymentMethod,
                    onChanged: (v) => setState(() => _paymentMethod = v ?? _paymentMethod),
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          title: const Text('Cash on Delivery'),
                          subtitle: const Text('Pay when you receive'),
                          secondary: const Icon(Icons.money),
                          value: 'cod',
                        ),
                        const Divider(height: 0),
                        RadioListTile<String>(
                          title: const Text('SSLCommerz'),
                          subtitle: const Text('Pay online securely'),
                          secondary: const Icon(Icons.credit_card),
                          value: 'sslcommerz',
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isPlacingOrder
                        ? null
                        : () => _showCheckoutDetails(cart),
                    child: _isPlacingOrder
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Review & Place Order — ${currency.format(cartModel.subtotal)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}
