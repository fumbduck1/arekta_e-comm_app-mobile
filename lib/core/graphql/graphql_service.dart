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

    final authLink = AuthLink(
      getToken: () async {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          return 'Bearer ${session.accessToken}';
        }
        return null;
      },
    );

    final roleLink = AuthLink(
      headerKey: 'x-hasura-role',
      getToken: () async {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) {
          debugPrint('[GraphQLService] Not authenticated, using public role');
          return _guestHasuraRole;
        }

        final role = _extractHasuraRoleFromJwt(session.accessToken);
        if (role == null) {
          debugPrint(
            '[GraphQLService] Authenticated, no trusted Hasura role found in JWT; relying on server-side JWT defaults',
          );
          return null;
        }

        debugPrint('[GraphQLService] Authenticated, using role: $role');
        return role;
      },
    );

    final userIdLink = AuthLink(
      headerKey: 'x-hasura-user-id',
      getToken: () async {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          final userId = session.user?.id;
          if (userId != null) {
            debugPrint('[GraphQLService] Setting X-Hasura-User-Id: $userId');
            return userId;
          }
        }
        return null;
      },
    );

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
            final userId = session.user?.id;
            if (userId != null) {
              headers['x-hasura-user-id'] = userId;
            }
            return {'headers': headers};
          }

          return {
            'headers': {'x-hasura-role': _guestHasuraRole},
          };
        },
      ),
    );

    // Use WebSocket for subscriptions, HTTP for queries/mutations
    final link = Link.split(
      (request) => request.isSubscription,
      wsLink,
      userIdLink.concat(roleLink).concat(authLink).concat(httpLink),
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
    final candidates = <dynamic>[
      customClaims?['x-hasura-default-role'],
      customClaims?['x-hasura-role'],
      claims['role'],
      (claims['app_metadata'] as Map<String, dynamic>?)?['role'],
      (claims['user_metadata'] as Map<String, dynamic>?)?['role'],
    ];

    for (final candidate in candidates) {
      if (candidate is! String) continue;
      if (_allowedHasuraRoles.contains(candidate)) {
        return candidate;
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
