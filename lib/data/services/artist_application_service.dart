import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/artist_application_model.dart';

/// Operations on `artist_applications`.
/// Users submit one application at a time; moderators approve/reject via RPC.
class ArtistApplicationService {
  ArtistApplicationService._();

  static SupabaseClient? _clientOverride;
  static SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  @visibleForTesting
  static set clientOverride(SupabaseClient? client) => _clientOverride = client;

  /// Returns the most recent application of the signed-in user, or null.
  static Future<ArtistApplication?> myLatest() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final row = await _client
        .from('artist_applications')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return ArtistApplication.fromMap(Map<String, dynamic>.from(row));
  }

  /// Submit a new application. Throws if a pending one already exists
  /// (DB unique partial index on user_id where status='pending').
  static Future<ArtistApplication> submit({
    required String artistName,
    required String reason,
    String? bio,
    String? links,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Не авторизован');
    }
    final inserted = await _client
        .from('artist_applications')
        .insert({
          'user_id': user.id,
          'artist_name': artistName.trim(),
          'reason': reason.trim(),
          'bio': bio?.trim(),
          'links': links?.trim(),
          'status': 'pending',
          'email': user.email,
          'username': user.userMetadata?['username'] ?? user.email?.split('@').first,
        })
        .select()
        .single();
    return ArtistApplication.fromMap(Map<String, dynamic>.from(inserted));
  }

  /// Withdraw a pending application (allowed by RLS for the owner).
  static Future<void> withdraw(String applicationId) async {
    await _client.from('artist_applications').delete().eq('id', applicationId);
  }

  /// Moderator: list applications by status (default pending).
  static Future<List<ArtistApplication>> queue({
    ArtistApplicationStatus status = ArtistApplicationStatus.pending,
    int limit = 100,
  }) async {
    final statusValue = status.name;
    final rows = await _client
        .from('artist_applications')
        .select()
        .eq('status', statusValue)
        .order('created_at', ascending: status == ArtistApplicationStatus.pending)
        .limit(limit);
    final list = (rows as List)
        .map((row) => ArtistApplication.fromMap(Map<String, dynamic>.from(row)))
        .toList();

    // Enrich with username/email from profiles (separate query — FK on
    // artist_applications.user_id points to auth.users, so PostgREST cannot
    // embed `profiles` via that FK).
    if (list.isEmpty) return list;
    final ids = list.map((a) => a.userId).toSet().toList();
    try {
      final profiles = await _client
          .from('profiles')
          .select('id, username, email')
          .inFilter('id', ids);
      final byId = <String, Map<String, dynamic>>{
        for (final p in (profiles as List))
          (p as Map)['id'] as String: Map<String, dynamic>.from(p),
      };
      return [
        for (final a in list)
          ArtistApplication(
            id: a.id,
            userId: a.userId,
            artistName: a.artistName,
            bio: a.bio,
            links: a.links,
            reason: a.reason,
            status: a.status,
            reviewerId: a.reviewerId,
            reviewerNote: a.reviewerNote,
            createdAt: a.createdAt,
            reviewedAt: a.reviewedAt,
            userEmail: byId[a.userId]?['email'] as String? ?? a.userEmail,
            username: byId[a.userId]?['username'] as String? ?? a.username,
          ),
      ];
    } catch (_) {
      return list;
    }
  }

  /// Moderator approves and grants 'artist' role atomically.
  static Future<void> approve(String applicationId, {String? note}) async {
    await _client.rpc(
      'approve_artist_application',
      params: {'application_id': applicationId, 'note': note},
    );
  }

  /// Moderator rejects with mandatory note.
  static Future<void> reject(String applicationId, String note) async {
    await _client.rpc(
      'reject_artist_application',
      params: {'application_id': applicationId, 'note': note},
    );
  }
}
