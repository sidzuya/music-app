import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/catalog_song_model.dart';

/// Reads/writes the unified `public.songs` table with status & is_featured.
/// Replaces direct usage of the legacy storage-only path for new code.
class SongsCatalogService {
  SongsCatalogService._();

  static SupabaseClient get _client => Supabase.instance.client;
  static const String songsBucket = 'songs';
  static const String coversBucket = 'covers';

  // ---------------------------------------------------------------- READ ----

  /// Approved songs visible to everyone (home, search, etc.).
  static Future<List<CatalogSong>> approved({int limit = 200}) async {
    final rows = await _client
        .from('songs')
        .select()
        .eq('status', 'approved')
        .order('created_at', ascending: false)
        .limit(limit);
    return _mapList(rows);
  }

  /// Full-text-ish search across approved songs (title/artist/album).
  static Future<List<CatalogSong>> searchApproved(
    String query, {
    int limit = 30,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    // Escape `%` and `,` to keep the .or() filter well-formed.
    final safe = q.replaceAll(',', ' ').replaceAll('%', r'\%');
    final rows = await _client
        .from('songs')
        .select()
        .eq('status', 'approved')
        .or('title.ilike.%$safe%,artist.ilike.%$safe%,album.ilike.%$safe%')
        .order('is_featured', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);
    return _mapList(rows);
  }

  /// Featured (curated by admin).
  static Future<List<CatalogSong>> featured({int limit = 20}) async {
    final rows = await _client
        .from('songs')
        .select()
        .eq('status', 'approved')
        .eq('is_featured', true)
        .order('created_at', ascending: false)
        .limit(limit);
    return _mapList(rows);
  }

  /// Songs owned by the current user (artist studio).
  static Future<List<CatalogSong>> mine({int limit = 200}) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    final rows = await _client
        .from('songs')
        .select()
        .eq('owner_id', user.id)
        .order('created_at', ascending: false)
        .limit(limit);
    return _mapList(rows);
  }

  /// Songs owned by a specific artist.
  static Future<List<CatalogSong>> fetchSongsByArtistId(String artistId, {int limit = 200}) async {
    final rows = await _client
        .from('songs')
        .select()
        .eq('owner_id', artistId)
        .eq('status', 'approved')
        .order('created_at', ascending: false)
        .limit(limit);
    return _mapList(rows);
  }

  /// Fetch a single catalog song by its UUID.
  static Future<CatalogSong?> fetchById(String songId) async {
    try {
      final row = await _client
          .from('songs')
          .select()
          .eq('id', songId)
          .maybeSingle();
      if (row == null) return null;
      return CatalogSong.fromMap(Map<String, dynamic>.from(row));
    } catch (_) {
      return null;
    }
  }

  /// Songs awaiting moderation (moderator queue).
  static Future<List<CatalogSong>> pending({int limit = 100}) async {
    final rows = await _client
        .from('songs')
        .select()
        .eq('status', 'pending')
        .order('created_at', ascending: true)
        .limit(limit);
    return _mapList(rows);
  }

  static List<CatalogSong> _mapList(dynamic rows) {
    return (rows as List)
        .map((r) => CatalogSong.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  // -------------------------------------------------------------- UPLOAD ----

  /// Artist upload — stores file under `songs/<uid>/<filename>`,
  /// optional cover under `covers/<uid>/<filename>`, then inserts a
  /// row with status='pending' awaiting moderator approval.
  static Future<CatalogSong> uploadAsArtist({
    required String title,
    required String artist,
    required Uint8List audioBytes,
    required String audioExtension,
    String? album,
    String? genre,
    int? durationSeconds,
    Uint8List? coverBytes,
    String? coverExtension,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Не авторизован');

    final base = _sanitize('${artist}_${title}_${DateTime.now().millisecondsSinceEpoch}');
    final audioPath = '${user.id}/$base.$audioExtension';

    await _client.storage
        .from(songsBucket)
        .uploadBinary(audioPath, audioBytes,
            fileOptions: const FileOptions(upsert: true));
    final audioUrl = _client.storage.from(songsBucket).getPublicUrl(audioPath);

    String? coverUrl;
    if (coverBytes != null && coverExtension != null) {
      final coverPath = '${user.id}/$base.$coverExtension';
      await _client.storage
          .from(coversBucket)
          .uploadBinary(coverPath, coverBytes,
              fileOptions: const FileOptions(upsert: true));
      coverUrl = _client.storage.from(coversBucket).getPublicUrl(coverPath);
    }

    final inserted = await _client
        .from('songs')
        .insert({
          'title': title.trim(),
          'artist': artist.trim(),
          'audio_url': audioUrl,
          'cover_url': coverUrl,
          'album': album?.trim(),
          'genre': genre?.trim(),
          'duration_seconds': durationSeconds,
          'owner_id': user.id,
          'uploaded_by': user.id,
          'status': 'pending',
          'is_featured': false,
        })
        .select()
        .single();
    return CatalogSong.fromMap(Map<String, dynamic>.from(inserted));
  }

  // ---------------------------------------------------------- MODERATION ---

  static Future<void> approve(String songId) async {
    await _client.rpc('approve_song', params: {'song_id': songId});
  }

  static Future<void> reject(String songId, String note) async {
    await _client.rpc('reject_song', params: {'song_id': songId, 'note': note});
  }

  // ------------------------------------------------------------- ADMIN ----

  /// Admin only — toggle the curated `is_featured` flag.
  static Future<void> setFeatured(String songId, bool featured) async {
    await _client
        .from('songs')
        .update({'is_featured': featured})
        .eq('id', songId);
  }

  /// Owner-or-staff delete. RLS enforces the actual permission.
  static Future<void> delete(String songId) async {
    await _client.from('songs').delete().eq('id', songId);
  }

  // ------------------------------------------------------------ HELPERS ----

  static String _sanitize(String input) {
    return input
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '')
        .toLowerCase();
  }
}
