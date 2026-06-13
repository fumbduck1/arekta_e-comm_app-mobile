import 'package:supabase_flutter/supabase_flutter.dart';

class RpcClient {
  static SupabaseClient get _supabase => Supabase.instance.client;

  static Future<Map<String, dynamic>> createOrderFromCart({
    required String userId,
    required String shippingAddress,
    required String paymentMethod,
    String? couponCode,
  }) async {
    final result = await _supabase.rpc('create_order_from_cart', params: {
      'p_user_id': userId,
      'p_shipping_address': shippingAddress,
      'p_payment_method': paymentMethod,
      'p_coupon_code': couponCode,
    });
    final data = result == null ? <String, dynamic>{} : Map<String, dynamic>.from(result);
    return data;
  }

  static Future<Map<String, dynamic>> approveProductForSale({
    required String productId,
    required String adminUserId,
    required String status,
    String? moderationNotes,
  }) async {
    final result = await _supabase.rpc('approve_product_for_sale', params: {
      'p_product_id': productId,
      'p_admin_user_id': adminUserId,
      'p_status': status,
      'p_moderation_notes': moderationNotes,
    });
    final data = result == null ? <String, dynamic>{} : Map<String, dynamic>.from(result);
    return data;
  }

  static Future<Map<String, dynamic>> validateCoupon({
    required String code,
    required num orderSubtotal,
  }) async {
    final result = await _supabase.rpc('validate_coupon_for_order', params: {
      'p_coupon_code': code,
      'p_order_subtotal': orderSubtotal,
    });
    final data = result == null ? <String, dynamic>{} : Map<String, dynamic>.from(result);
    return data;
  }

  static Future<List<dynamic>> getActiveCoupons({
    num? orderSubtotal,
  }) async {
    final result = await _supabase.rpc('get_active_coupons_for_user', params: {
      'p_order_subtotal': orderSubtotal,
    });
    return result == null ? [] : result as List<dynamic>;
  }
}
