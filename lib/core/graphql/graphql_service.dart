import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

import '../constants/app_constants.dart';

/// Singleton GraphQL client that attaches the Supabase JWT to every request
class GraphQLService {
  GraphQLService._();
  static final GraphQLService _instance = GraphQLService._();
  static GraphQLService get instance => _instance;

  static const String _guestHasuraRole = 'public';
  static const Set<String> _allowedHasuraRoles = {
    'public',
    'client',
    'vendor',
    'super_admin',
  };

  late ValueNotifier<GraphQLClient> client;

  /// Call once at app start (after Supabase is initialized)
  void init() {
    client = ValueNotifier(_buildClient());
  }

  /// Refresh the client (e.g., after login/logout)
  void refresh() {
    client.value = _buildClient();
  }

  GraphQLClient _buildClient() {
    final httpLink = HttpLink(AppConstants.hasuraHttpEndpoint);

    final authHeadersLink = Link.function((request, [forward]) async* {
      if (forward == null) {
        return;
      }

      final session = Supabase.instance.client.auth.currentSession;
      final derivedHeaders = <String, String>{};

      if (session != null) {
        derivedHeaders['Authorization'] = 'Bearer ${session.accessToken}';

        final role = _extractHasuraRoleFromJwt(session.accessToken);
        if (role != null) {
          derivedHeaders['x-hasura-role'] = role;
        }

        final claims = _decodeJwtClaims(session.accessToken);
        if (claims != null) {
          final hasuraClaims = _extractHasuraClaims(claims);
          final userId = hasuraClaims?['x-hasura-user-id'] ?? claims['sub'];
          if (userId is String && userId.isNotEmpty) {
            derivedHeaders['x-hasura-user-id'] = userId;
          }
        }
      } else {
        derivedHeaders['x-hasura-role'] = _guestHasuraRole;
      }

      final updatedRequest = request.updateContextEntry<HttpLinkHeaders>((
        existing,
      ) {
        return HttpLinkHeaders(
          headers: {...derivedHeaders, ...?existing?.headers},
        );
      });

      yield* forward(updatedRequest);
    });

    final wsLink = WebSocketLink(
      AppConstants.hasuraWsEndpoint,
      config: SocketClientConfig(
        autoReconnect: true,
        inactivityTimeout: const Duration(seconds: 30),
        initialPayload: () async {
          final session = Supabase.instance.client.auth.currentSession;
          if (session != null) {
            final headers = <String, String>{
              'Authorization': 'Bearer ${session.accessToken}',
            };
            final role = _extractHasuraRoleFromJwt(session.accessToken);
            if (role != null) {
              headers['x-hasura-role'] = role;
            }
            // Add user ID from JWT claims
            final claims = _decodeJwtClaims(session.accessToken);
            if (claims != null) {
              final hasuraClaims = _extractHasuraClaims(claims);
              final userId = hasuraClaims?['x-hasura-user-id'] ?? claims['sub'];
              if (userId is String && userId.isNotEmpty) {
                headers['x-hasura-user-id'] = userId;
              }
            }
            return {'headers': headers};
          }

          return {
            'headers': {'x-hasura-role': _guestHasuraRole},
          };
        },
      ),
    );

    // Use one async header link to avoid nested async auth transforms.
    final link = Link.split(
      (request) => request.isSubscription,
      wsLink,
      authHeadersLink.concat(httpLink),
    );

    return GraphQLClient(
      link: link,
      cache: GraphQLCache(store: InMemoryStore()),
    );
  }

  String? _extractHasuraRoleFromJwt(String token) {
    final claims = _decodeJwtClaims(token);
    if (claims == null) return null;

    final customClaims = _extractHasuraClaims(claims);
    final appMetadata = claims['app_metadata'] as Map<String, dynamic>?;
    final userMetadata = claims['user_metadata'] as Map<String, dynamic>?;

    final candidates = <dynamic>[
      customClaims?['x-hasura-default-role'],
      customClaims?['x-hasura-role'],
      customClaims?['X-Hasura-Default-Role'],
      customClaims?['X-Hasura-Role'],
      claims['role'],
      appMetadata?['role'],
      appMetadata?['default_role'],
      userMetadata?['role'],
      userMetadata?['default_role'],
    ];

    for (final candidate in candidates) {
      if (candidate is! String) continue;
      if (_allowedHasuraRoles.contains(candidate)) {
        return candidate;
      }
    }

    final allowedRoles = customClaims?['x-hasura-allowed-roles'];
    if (allowedRoles is List) {
      for (final role in allowedRoles) {
        if (role is String && _allowedHasuraRoles.contains(role)) {
          return role;
        }
      }
    }

    return null;
  }

  Map<String, dynamic>? _decodeJwtClaims(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;

    try {
      var payload = parts[1];
      payload = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(payload));
      final json = jsonDecode(decoded);
      if (json is Map<String, dynamic>) {
        return json;
      }
    } catch (error) {
      debugPrint('[GraphQLService] Failed to decode JWT payload: $error');
    }

    return null;
  }

  Map<String, dynamic>? _extractHasuraClaims(Map<String, dynamic> claims) {
    const claimKeys = [
      'https://hasura.io/jwt/claims',
      'https://hasura.io/jwt/claims/',
      'hasura_claims',
    ];

    for (final key in claimKeys) {
      final value = claims[key];
      if (value is Map<String, dynamic>) {
        return value;
      }
    }

    return null;
  }
}
