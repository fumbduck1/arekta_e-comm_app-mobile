import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/subscription_plan_model.dart';

class OperatorProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<SubscriptionPlan> _plans = [];
  MarketplaceSubscription? _subscription;
  bool _isLoading = false;
  String? _error;

  List<SubscriptionPlan> get plans => _plans;
  MarketplaceSubscription? get subscription => _subscription;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadPlans() async {
    _setLoading();
    try {
      final data = await _supabase
          .from('subscription_plans')
          .select()
          .eq('is_active', true)
          .order('price');
      _plans = (data as List)
          .cast<Map<String, dynamic>>()
          .map((e) => SubscriptionPlan.fromJson(e))
          .toList();
      _error = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _setError(e);
    }
  }

  Future<void> loadSubscription(String marketplaceId) async {
    _setLoading();
    try {
      final data = await _supabase
          .from('marketplace_subscriptions')
          .select()
          .eq('marketplace_id', marketplaceId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (data != null) {
        _subscription = MarketplaceSubscription.fromJson(data);
      }
      _error = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _setError(e);
    }
  }

  Future<bool> createMarketplaceSubscription({
    required String marketplaceId,
    required String planId,
    required String paymentMethod,
    String? paymentTrxId,
  }) async {
    try {
      final plan = _plans.firstWhere((p) => p.id == planId);
      final periodEnd = DateTime.now().add(
        plan.interval == 'yearly'
            ? const Duration(days: 365)
            : const Duration(days: 30),
      );

      await _supabase.from('marketplace_subscriptions').insert({
        'marketplace_id': marketplaceId,
        'plan_id': planId,
        'status': 'active',
        'current_period_start': DateTime.now().toIso8601String(),
        'current_period_end': periodEnd.toIso8601String(),
        'payment_method': paymentMethod,
        'payment_trx_id': paymentTrxId,
      });

      await loadSubscription(marketplaceId);
      return true;
    } catch (e) {
      debugPrint('Error creating subscription: $e');
      _error = 'Failed to create subscription';
      notifyListeners();
      return false;
    }
  }

  void _setLoading() {
    _isLoading = true;
    _error = null;
    notifyListeners();
  }

  void _setError(Object e) {
    debugPrint('OperatorProvider error: $e');
    _error = 'An unexpected error occurred';
    _isLoading = false;
    notifyListeners();
  }
}
