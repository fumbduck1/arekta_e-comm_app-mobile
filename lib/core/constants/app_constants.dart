import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

/// Application-wide constants
class AppConstants {
  AppConstants._();

  // ── App Info ──────────────────────────────────────────────
  static const String appName = 'Arekta e-commerce app';
  static const String appTagline = 'Shop smart, shop local';

  // ── Supabase ──────────────────────────────────────────────
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  // ── SSLCommerz ────────────────────────────────────────────
  static String get sslCommerzStoreId =>
      dotenv.env['SSLCOMMERZ_STORE_ID'] ?? '';
  static String get sslCommerzStorePassword =>
      dotenv.env['SSLCOMMERZ_STORE_PASSWORD'] ?? '';
  static bool get sslCommerzSandbox =>
      dotenv.env['SSLCOMMERZ_SANDBOX']?.toLowerCase() == 'true';

  // ── Pagination ────────────────────────────────────────────
  static const int defaultPageSize = 20;

  // ── Storage Buckets ───────────────────────────────────────
  static const String productImagesBucket = 'product-images';
  static const String avatarsBucket = 'avatars';
  static const String carouselBucket = 'carousels';

  /// Checks if all required environment variables are present
  /// Throws an exception if any required variables are missing
  static void validateEnvVars() {
    final requiredVars = [
      'SUPABASE_URL',
      'SUPABASE_ANON_KEY',
    ];

    final missingVars = <String>[];

    for (final varName in requiredVars) {
      final value = dotenv.env[varName];
      if (value == null || value.isEmpty) {
        missingVars.add(varName);
      }
    }

    if (missingVars.isNotEmpty) {
      throw Exception(
        'Missing required environment variables: ${missingVars.join(', ')}\n'
        'Please check your .env file',
      );
    }
  }

  /// Checks if all required environment variables are present (non-throwing)
  static bool get areEnvVarsValid {
    final requiredVars = [
      'SUPABASE_URL',
      'SUPABASE_ANON_KEY',
    ];

    return requiredVars.every((varName) {
      final value = dotenv.env[varName];
      if (value == null || value.isEmpty) {
        debugPrint('Missing required environment variable: $varName');
        return false;
      }
      return true;
    });
  }
}
