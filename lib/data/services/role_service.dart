import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_role.dart';

/// Resolves and caches the current user's role from `profiles.role`.
/// Use this instead of the legacy [AdminAccessService] going forward.
class RoleService {
  RoleService._();

  static SupabaseClient? _clientOverride;
  static SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  @visibleForTesting
  static set clientOverride(SupabaseClient? client) => _clientOverride = client;

  // Cached role for the current session, keyed by user id.
  static String? _cachedUserId;
  static UserRole? _cachedRole;

  @visibleForTesting
  static void setMockRole(String? userId, UserRole? role) {
    _cachedUserId = userId;
    _cachedRole = role;
  }

  /// Force-refresh the cached role on next read.
  static void invalidate() {
    _cachedUserId = null;
    _cachedRole = null;
  }

  /// Returns the role of the currently authenticated user.
  /// Defaults to [UserRole.user] if not authenticated or on error.
  static Future<UserRole> currentRole({bool forceRefresh = false}) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      invalidate();
      return UserRole.user;
    }

    if (!forceRefresh && _cachedUserId == user.id && _cachedRole != null) {
      return _cachedRole!;
    }

    try {
      final row = await _client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      final role = UserRole.fromString(row?['role'] as String?);
      _cachedUserId = user.id;
      _cachedRole = role;
      return role;
    } catch (e) {
      debugPrint('RoleService.currentRole failed: $e');
      return UserRole.user;
    }
  }

  static Future<bool> isAdmin() async => (await currentRole()).isAdmin;
  static Future<bool> isModerator() async =>
      (await currentRole()).isModerator;
  static Future<bool> isArtist() async => (await currentRole()).isArtist;

  /// Admin only — set role of any user via the `set_user_role` RPC.
  static Future<void> setUserRole(String userId, UserRole role) async {
    await _client.rpc(
      'set_user_role',
      params: {'target_user': userId, 'new_role': role.value},
    );
    if (userId == _client.auth.currentUser?.id) {
      invalidate();
    }
  }

  /// List profiles by role (for admin moderator-management screens).
  static Future<List<Map<String, dynamic>>> listProfilesByRole(
    UserRole role,
  ) async {
    final rows = await _client
        .from('profiles')
        .select('id, username, email, role, profile_image, created_at')
        .eq('role', role.value)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Search profiles for granting roles.
  static Future<List<Map<String, dynamic>>> searchProfiles(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final rows = await _client
        .from('profiles')
        .select('id, username, email, role')
        .or('username.ilike.%$q%,email.ilike.%$q%')
        .limit(25);
    return List<Map<String, dynamic>>.from(rows as List);
  }
}
