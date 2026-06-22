import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminAccessService {
  const AdminAccessService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<bool> isCurrentUserAdmin() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      final result = await _client.rpc('is_admin');
      return result == true;
    } catch (e) {
      debugPrint('AdminAccessService: RPC is_admin failed: $e');
    }

    try {
      final row = await _client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      return row != null && row['role'] == 'admin';
    } catch (e) {
      debugPrint('AdminAccessService: direct role check failed: $e');
      return false;
    }
  }
}
