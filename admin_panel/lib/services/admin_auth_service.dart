import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminAuthService {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<bool> signIn(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (response.session == null) return false;
    return isAdmin();
  }

  static Future<bool> isAdmin() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      debugPrint('AdminAuth: no current user');
      return false;
    }
    debugPrint('AdminAuth: checking role for user ${user.id}');
    try {
      // Use RPC to avoid RLS recursion on profiles table
      final result = await _client.rpc('is_admin');
      debugPrint('AdminAuth: rpc result = $result');
      return result == true;
    } catch (e) {
      debugPrint('AdminAuth: RPC failed ($e), trying direct query...');
      // Fallback: direct query
      try {
        final row = await _client
            .from('profiles')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();
        return row != null && row['role'] == 'admin';
      } catch (e2) {
        debugPrint('AdminAuth: direct query also failed: $e2');
        return false;
      }
    }
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
