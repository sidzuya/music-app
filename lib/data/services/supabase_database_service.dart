import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart';
import 'playlist_remote_writer.dart';

/// Service for syncing data with Supabase database tables
class SupabaseDatabaseService implements PlaylistRemoteWriter {
  static final SupabaseDatabaseService _instance = SupabaseDatabaseService._internal();
  
  SupabaseClient? _clientOverride;
  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  factory SupabaseDatabaseService({SupabaseClient? client}) {
    if (client != null) {
      _instance._clientOverride = client;
    }
    return _instance;
  }
  
  SupabaseDatabaseService._internal();

  @visibleForTesting
  SupabaseDatabaseService.forTesting();

  String? get _userId => _client.auth.currentUser?.id;
  
  String? _cachedUsername;
  
  /// Get username from profiles table or email
  Future<String?> _getUsername() async {
    if (_cachedUsername != null) return _cachedUsername;
    
    final user = _client.auth.currentUser;
    if (user == null) return null;
    
    try {
      // Try to get username from profiles table
      final response = await _client
          .from('profiles')
          .select('username')
          .eq('id', user.id)
          .maybeSingle();
      
      if (response != null && response['username'] != null) {
        _cachedUsername = response['username'] as String;
        return _cachedUsername;
      }
    } catch (e) {
      debugPrint('Error fetching username from profiles: $e');
    }
    
    // Fallback to email
    _cachedUsername = user.email?.split('@').first ?? 'User';
    return _cachedUsername;
  }
  
  /// Clear cached username (call on logout)
  void clearCache() {
    _cachedUsername = null;
  }

  // ============ USER FAVORITES ============

  /// Get all favorites for current user
  Future<List<SongModel>> getFavorites() async {
    try {
      if (_userId == null) {
        debugPrint('SupabaseDatabaseService: No user logged in');
        return [];
      }

      final response = await _client
          .from('user_favorites')
          .select()
          .eq('user_id', _userId!)
          .order('added_at', ascending: false);

      debugPrint('SupabaseDatabaseService: Loaded ${response.length} favorites from Supabase');

      return (response as List).map((json) => SongModel(
        id: json['id'].hashCode,
        title: json['song_title'] ?? '',
        artist: json['song_artist'] ?? '',
        album: json['song_album'] ?? 'Unknown',
        audioUrl: json['song_audio_url'],
        duration: Duration.zero,
        genre: 'Unknown',
        createdAt: DateTime.parse(json['added_at']),
        isFavorite: true,
      )).toList();
    } catch (e) {
      debugPrint('SupabaseDatabaseService.getFavorites error: $e');
      return [];
    }
  }

  /// Add song to favorites
  Future<bool> addToFavorites(SongModel song) async {
    try {
      if (_userId == null) return false;

      await _client.from('user_favorites').insert({
        'user_id': _userId,
        'username': await _getUsername(),
        'song_title': song.title,
        'song_artist': song.artist,
        'song_audio_url': song.audioUrl,
        'song_album': song.album,
      });

      debugPrint('SupabaseDatabaseService: Added "${song.title}" to favorites');
      return true;
    } catch (e) {
      debugPrint('SupabaseDatabaseService.addToFavorites error: $e');
      return false;
    }
  }

  /// Remove song from favorites
  Future<bool> removeFromFavorites(SongModel song) async {
    try {
      if (_userId == null) return false;

      await _client
          .from('user_favorites')
          .delete()
          .eq('user_id', _userId!)
          .eq('song_title', song.title)
          .eq('song_artist', song.artist);

      debugPrint('SupabaseDatabaseService: Removed "${song.title}" from favorites');
      return true;
    } catch (e) {
      debugPrint('SupabaseDatabaseService.removeFromFavorites error: $e');
      return false;
    }
  }

  /// Check if song is favorite
  Future<bool> isFavorite(SongModel song) async {
    try {
      if (_userId == null) return false;

      final response = await _client
          .from('user_favorites')
          .select('id')
          .eq('user_id', _userId!)
          .eq('song_title', song.title)
          .eq('song_artist', song.artist)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('SupabaseDatabaseService.isFavorite error: $e');
      return false;
    }
  }

  // ============ PLAYLISTS ============

  /// Get all playlists for current user (returns raw data for UUID mapping)
  Future<List<Map<String, dynamic>>> getPlaylists() async {
    try {
      if (_userId == null) return [];

      final response = await _client
          .from('playlists')
          .select()
          .eq('user_id', _userId!)
          .order('created_at', ascending: false);

      debugPrint('SupabaseDatabaseService: Loaded ${response.length} playlists from Supabase');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('SupabaseDatabaseService.getPlaylists error: $e');
      return [];
    }
  }

  /// Create new playlist
  Future<String?> createPlaylist(String name, String? description) async {
    try {
      if (_userId == null) return null;

      final response = await _client
          .from('playlists')
          .insert({
            'user_id': _userId,
            'username': await _getUsername(),
            'name': name,
            'description': description,
          })
          .select('id')
          .single();

      debugPrint('SupabaseDatabaseService: Created playlist "$name"');
      return response['id'] as String;
    } catch (e) {
      debugPrint('SupabaseDatabaseService.createPlaylist error: $e');
      return null;
    }
  }

  /// Delete playlist
  Future<bool> deletePlaylist(String playlistId) async {
    try {
      if (_userId == null) return false;

      // Manually cascade delete from playlist_collaborators (since it uses TEXT id)
      await _client
          .from('playlist_collaborators')
          .delete()
          .eq('playlist_id', playlistId);

      // Manually cascade delete from playlist_songs
      await _client
          .from('playlist_songs')
          .delete()
          .eq('playlist_id', playlistId);

      await _client
          .from('playlists')
          .delete()
          .eq('id', playlistId)
          .eq('user_id', _userId!);

      debugPrint('SupabaseDatabaseService: Deleted playlist $playlistId');
      return true;
    } catch (e) {
      debugPrint('SupabaseDatabaseService.deletePlaylist error: $e');
      return false;
    }
  }

  /// Update playlist
  Future<bool> updatePlaylist(String playlistId, String name, String? description) async {
    try {
      if (_userId == null) return false;

      await _client
          .from('playlists')
          .update({
            'name': name,
            'description': description,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', playlistId)
          .eq('user_id', _userId!);

      debugPrint('SupabaseDatabaseService: Updated playlist $playlistId');
      return true;
    } catch (e) {
      debugPrint('SupabaseDatabaseService.updatePlaylist error: $e');
      return false;
    }
  }

  /// Search playlists by name across all users (public discovery).
  ///
  /// Returns up to [limit] rows matching the query (case-insensitive ILIKE).
  /// Returns an empty list if anything goes wrong (table missing, RLS, etc).
  Future<List<Map<String, dynamic>>> searchPublicPlaylists(
    String query, {
    int limit = 30,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final pattern = '%${trimmed.replaceAll('%', r'\%')}%';
    try {
      final response = await _client
          .from('playlists')
          .select('id, name, description, cover_url, user_id, username')
          .ilike('name', pattern)
          .limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('SupabaseDatabaseService.searchPublicPlaylists error: $e');
      return const [];
    }
  }

  /// Get playlists owned by a specific user (for their public profile).
  Future<List<Map<String, dynamic>>> getUserPlaylists(String userId) async {
    try {
      final response = await _client
          .from('playlists')
          .select('id, name, description, cover_url, user_id, username')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('SupabaseDatabaseService.getUserPlaylists error: $e');
      return const [];
    }
  }

  // ============ PLAYLIST SONGS ============

  /// Get songs in a playlist
  Future<List<SongModel>> getPlaylistSongs(String playlistId) async {
    try {
      final response = await _client
          .from('playlist_songs')
          .select()
          .eq('playlist_id', playlistId)
          .order('position', ascending: true);

      debugPrint('SupabaseDatabaseService: Loaded ${response.length} songs from playlist $playlistId');

      return (response as List).map((json) {
        final title = json['song_title'] ?? '';
        // album art: try song_cover_url column first, then fall back to featured lookup
        String? albumArt = json['song_cover_url'] as String?;
        if (albumArt == null || albumArt.isEmpty) {
          albumArt = json['song_album_art'] as String?;
        }
        return SongModel(
          id: json['id'].hashCode,
          title: title,
          artist: json['song_artist'] ?? '',
          album: json['song_album'] ?? 'Unknown',
          albumArt: albumArt,
          audioUrl: json['song_audio_url'],
          duration: Duration.zero,
          genre: 'Unknown',
          createdAt: DateTime.parse(json['added_at']),
        );
      }).toList();
    } catch (e) {
      debugPrint('SupabaseDatabaseService.getPlaylistSongs error: $e');
      return [];
    }
  }

  /// Add song to playlist
  Future<bool> addSongToPlaylist(String playlistId, SongModel song) async {
    try {
      // Get current max position
      final positionResponse = await _client
          .from('playlist_songs')
          .select('position')
          .eq('playlist_id', playlistId)
          .order('position', ascending: false)
          .limit(1)
          .maybeSingle();

      final nextPosition = (positionResponse?['position'] ?? -1) + 1;

      await _client.from('playlist_songs').insert({
        'playlist_id': playlistId,
        'username': await _getUsername(),
        'song_title': song.title,
        'song_artist': song.artist,
        'song_audio_url': song.audioUrl,
        'song_album': song.album,
        'position': nextPosition,
      });

      debugPrint('SupabaseDatabaseService: Added "${song.title}" to playlist $playlistId');
      return true;
    } catch (e) {
      debugPrint('SupabaseDatabaseService.addSongToPlaylist error: $e');
      return false;
    }
  }

  /// Remove song from playlist
  Future<bool> removeSongFromPlaylist(String playlistId, SongModel song) async {
    try {
      await _client
          .from('playlist_songs')
          .delete()
          .eq('playlist_id', playlistId)
          .eq('song_title', song.title)
          .eq('song_artist', song.artist);

      debugPrint('SupabaseDatabaseService: Removed "${song.title}" from playlist $playlistId');
      return true;
    } catch (e) {
      debugPrint('SupabaseDatabaseService.removeSongFromPlaylist error: $e');
      return false;
    }
  }

  // ============ LISTENING HISTORY ============

  /// Add song to listening history
  Future<bool> addToHistory(SongModel song, int durationListened) async {
    try {
      if (_userId == null) return false;

      await _client.from('listening_history').insert({
        'user_id': _userId,
        'username': await _getUsername(),
        'song_title': song.title,
        'song_artist': song.artist,
        'duration_listened': durationListened,
      });

      debugPrint('SupabaseDatabaseService: Added "${song.title}" to history');
      return true;
    } catch (e) {
      debugPrint('SupabaseDatabaseService.addToHistory error: $e');
      return false;
    }
  }

  /// Get listening history
  Future<List<Map<String, dynamic>>> getListeningHistory({int limit = 50}) async {
    try {
      if (_userId == null) return [];

      final response = await _client
          .from('listening_history')
          .select()
          .eq('user_id', _userId!)
          .order('listened_at', ascending: false)
          .limit(limit);

      debugPrint('SupabaseDatabaseService: Loaded ${response.length} history items');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('SupabaseDatabaseService.getListeningHistory error: $e');
      return [];
    }
  }
}
