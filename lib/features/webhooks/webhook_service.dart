import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/webhook_event_model.dart';

class WebhookService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<WebhookEvent>> getPendingEvents() async {
    final data = await _supabase
        .from('webhook_events')
        .select()
        .eq('status', 'pending')
        .order('created_at')
        .limit(50);
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map((e) => WebhookEvent.fromJson(e))
        .toList();
  }

  Future<List<WebhookConfig>> getActiveConfigs() async {
    final data = await _supabase
        .from('webhook_configs')
        .select()
        .eq('is_active', true);
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map((e) => WebhookConfig.fromJson(e))
        .toList();
  }

  Future<void> processPendingEvents() async {
    final events = await getPendingEvents();
    final configs = await getActiveConfigs();
    final configMap = {for (var c in configs) c.eventType: c};

    for (final event in events) {
      final config = configMap[event.eventType];
      if (config == null) {
        await _markFailed(event.id, 'No active webhook config');
        continue;
      }

      try {
        await _deliver(event, config.destinationUrl);
        await _supabase
            .from('webhook_events')
            .update({
              'status': 'delivered',
              'delivered_at': DateTime.now().toIso8601String(),
            })
            .eq('id', event.id);
      } catch (e) {
        debugPrint('Webhook delivery failed for ${event.id}: $e');
        final newRetryCount = event.retryCount + 1;

        if (newRetryCount >= event.maxRetries) {
          await _supabase.from('webhook_events').update({
            'status': 'failed',
            'retry_count': newRetryCount,
            'last_error': e.toString(),
          }).eq('id', event.id);
        } else {
          final backoffSeconds = pow(2, newRetryCount) * 60;
          await _supabase.from('webhook_events').update({
            'status': 'pending',
            'retry_count': newRetryCount,
            'last_error': e.toString(),
            'next_retry_at': DateTime.now()
                .add(Duration(seconds: backoffSeconds.toInt()))
                .toIso8601String(),
          }).eq('id', event.id);
        }
      }
    }
  }

  Future<void> _deliver(WebhookEvent event, String url) async {
    // Webhook delivery via HTTP POST.
    // Uses dart:io HttpClient or a package like http.
    // For now, this logs and simulates delivery.
    debugPrint('Delivering webhook ${event.eventType} to $url');
    debugPrint('Payload: ${jsonEncode(event.payload)}');

    // In production, use http.post(Uri.parse(url), ...)
    // For now, mark as delivered if url is configured
    if (url.isEmpty) {
      throw Exception('No destination URL configured');
    }
  }

  Future<void> _markFailed(String eventId, String error) async {
    await _supabase.from('webhook_events').update({
      'status': 'failed',
      'last_error': error,
    }).eq('id', eventId);
  }

  Future<List<WebhookEvent>> getEventHistory({
    int limit = 50,
    String? statusFilter,
  }) async {
    var query = _supabase.from('webhook_events').select();

    if (statusFilter != null) {
      query = query.eq('status', statusFilter);
    }

    final data = await query
        .order('created_at', ascending: false)
        .limit(limit);
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map((e) => WebhookEvent.fromJson(e))
        .toList();
  }

  Future<bool> updateWebhookConfig({
    required String eventType,
    required String destinationUrl,
    String? secretKey,
  }) async {
    try {
      final existing = await _supabase
          .from('webhook_configs')
          .select('id')
          .eq('event_type', eventType)
          .maybeSingle();

      if (existing != null) {
        await _supabase.from('webhook_configs').update({
          'destination_url': destinationUrl,
          if (secretKey != null) 'secret_key': secretKey,
        }).eq('event_type', eventType);
      } else {
        await _supabase.from('webhook_configs').insert({
          'event_type': eventType,
          'destination_url': destinationUrl,
          if (secretKey != null) 'secret_key': secretKey,
        });
      }
      return true;
    } catch (e) {
      debugPrint('Error updating webhook config: $e');
      return false;
    }
  }
}
