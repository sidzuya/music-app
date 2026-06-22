import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/collab_playlist_model.dart';
import '../models/song_model.dart';

class CollabPlaylistService {
  final SupabaseClient _client;

  CollabPlaylistService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  String? get _userId => _client.auth.currentUser?.id;

  /// Invite a friend to collaborate on a playlist.
  /// Creates a pending invite and sends a notification.
  Future<bool> inviteCollaborator({
    required String playlistId,
    required String playlistName,
    required String friendId,
  }) async {
    final me = _userId;
    if (me == null) return false;

    try {
      // Get my username for the notification
      final myProfile = await _client
          .from('profiles')
          .select('username, profile_image')
          .eq('id', me)
          .maybeSingle();
      final myUsername = myProfile?['username'] ?? 'Пользователь';

      // Insert collaborator record (pending)
      await _client.from('playlist_collaborators').upsert(
        {
          'playlist_id': playlistId,
          'user_id': friendId,
          'invited_by': me,
          'status': 'pending',
        },
        onConflict: 'playlist_id,user_id',
      );

      // Try to send notification, ignore RLS errors if it fails
      try {
        await _client.from('notifications').insert({
          'user_id': friendId,
          'type': 'collab_invite',
          'title': '$myUsername приглашает вас',
          'message': 'Совместный плейлист: "$playlistName"',
          'data': {
            'playlist_id': playlistId,
            'playlist_name': playlistName,
            'invited_by': me,
            'invited_by_username': myUsername,
            'invited_by_avatar_url': myProfile?['profile_image'],
          },
        });
      } catch (_) {}

      debugPrint('CollabPlaylistService: Invited $friendId to playlist $playlistId');
      return true;
    } catch (e) {
      debugPrint('CollabPlaylistService.inviteCollaborator error: $e');
      return false;
    }
  }

  /// Accept a collaboration invite
  Future<bool> acceptInvite(String playlistId) async {
    final me = _userId;
    if (me == null) return false;

    try {
      await _client
          .from('playlist_collaborators')
          .update({'status': 'accepted'})
          .eq('playlist_id', playlistId)
          .eq('user_id', me);

      debugPrint('CollabPlaylistService: Accepted invite to playlist $playlistId');
      return true;
    } catch (e) {
      debugPrint('CollabPlaylistService.acceptInvite error: $e');
      return false;
    }
  }

  /// Decline a collaboration invite
  Future<bool> declineInvite(String playlistId) async {
    final me = _userId;
    if (me == null) return false;

    try {
      await _client
          .from('playlist_collaborators')
          .update({'status': 'declined'})
          .eq('playlist_id', playlistId)
          .eq('user_id', me);

      debugPrint('CollabPlaylistService: Declined invite to playlist $playlistId');
      return true;
    } catch (e) {
      debugPrint('CollabPlaylistService.declineInvite error: $e');
      return false;
    }
  }

  /// Get all playlists where I am an accepted collaborator (not the owner)
  Future<List<Map<String, dynamic>>> getMyCollabPlaylists() async {
    final me = _userId;
    if (me == null) return [];

    try {
      final response = await _client
          .from('playlist_collaborators')
          .select('playlist_id, status')
          .eq('user_id', me)
          .eq('status', 'accepted');

      if (response.isEmpty) return [];

      final playlistIds = (response as List)
          .map((r) => r['playlist_id'] as String)
          .toList();

      final uuidRegExp = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
      final validPlaylistIds = playlistIds.where((id) => uuidRegExp.hasMatch(id)).toList();

      if (validPlaylistIds.isEmpty) return [];

      final playlists = await _client
          .from('playlists')
          .select('id, name, description, cover_url, user_id, username')
          .inFilter('id', validPlaylistIds);

      return List<Map<String, dynamic>>.from(playlists);
    } catch (e) {
      debugPrint('CollabPlaylistService.getMyCollabPlaylists error: $e');
      return [];
    }
  }

  /// Get collaborators for a playlist
  Future<List<Map<String, dynamic>>> getCollaborators(String playlistId) async {
    try {
      final response = await _client
          .from('playlist_collaborators')
          .select('user_id, status, invited_by')
          .eq('playlist_id', playlistId)
          .eq('status', 'accepted');

      if (response.isEmpty) return [];

      final userIds = (response as List)
          .map((r) => r['user_id'] as String)
          .toList();

      final profiles = await _client
          .from('profiles')
          .select('id, username, profile_image')
          .inFilter('id', userIds);

      return List<Map<String, dynamic>>.from(profiles);
    } catch (e) {
      debugPrint('CollabPlaylistService.getCollaborators error: $e');
      return [];
    }
  }

  /// Check if current user is a collaborator on this playlist
  Future<bool> isCollaborator(String playlistId) async {
    final me = _userId;
    if (me == null) return false;

    try {
      final result = await _client
          .from('playlist_collaborators')
          .select('id')
          .eq('playlist_id', playlistId)
          .eq('user_id', me)
          .eq('status', 'accepted')
          .maybeSingle();
      return result != null;
    } catch (e) {
      return false;
    }
  }

  /// Get pending invites for me
  Future<List<CollabPlaylistModel>> getPendingInvites() async {
    final me = _userId;
    if (me == null) return [];

    try {
      final response = await _client
          .from('playlist_collaborators')
          .select('*')
          .eq('user_id', me)
          .eq('status', 'pending');

      if (response.isEmpty) return [];

      // Fetch playlist names
      final playlistIds = (response as List).map((r) => r['playlist_id'] as String).toList();
      final invitedByIds = (response).map((r) => r['invited_by'] as String).toList();

      final uuidRegExp = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
      final validPlaylistIds = playlistIds.where((id) => uuidRegExp.hasMatch(id)).toList();

      final playlists = validPlaylistIds.isNotEmpty 
          ? await _client.from('playlists').select('id, name').inFilter('id', validPlaylistIds)
          : [];
      final profiles = await _client.from('profiles').select('id, username, profile_image').inFilter('id', invitedByIds);

      final playlistMap = {for (var p in playlists as List) p['id']: p['name']};
      final profileMap = {
        for (var p in profiles as List) p['id']: {'username': p['username'], 'avatar_url': p['profile_image']}
      };

      return response.map((r) {
        return CollabPlaylistModel(
          id: r['id'] as String,
          playlistId: r['playlist_id'] as String,
          userId: r['user_id'] as String,
          invitedBy: r['invited_by'] as String,
          status: r['status'] as String,
          createdAt: DateTime.parse(r['created_at'] as String),
          playlistName: playlistMap[r['playlist_id']] as String?,
          invitedByUsername: profileMap[r['invited_by']]?['username'] as String?,
          invitedByAvatarUrl: profileMap[r['invited_by']]?['avatar_url'] as String?,
        );
      }).toList();
    } catch (e) {
      debugPrint('CollabPlaylistService.getPendingInvites error: $e');
      return [];
    }
  }

  /// Leave a collaborative playlist
  Future<bool> leavePlaylist(String playlistId) async {
    final me = _userId;
    if (me == null) return false;

    try {
      await _client
          .from('playlist_collaborators')
          .delete()
          .eq('playlist_id', playlistId)
          .eq('user_id', me);
      return true;
    } catch (e) {
      debugPrint('CollabPlaylistService.leavePlaylist error: $e');
      return false;
    }
  }

  /// Add song to collab playlist with "added by" tracking
  Future<bool> addSongWithCredit(String playlistId, SongModel song) async {
    final me = _userId;
    if (me == null) return false;

    try {
      final myProfile = await _client
          .from('profiles')
          .select('username')
          .eq('id', me)
          .maybeSingle();
      final myUsername = myProfile?['username'] ?? 'Unknown';

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
        'username': myUsername,
        'song_title': song.title,
        'song_artist': song.artist,
        'song_audio_url': song.audioUrl,
        'song_album': song.album,
        'position': nextPosition,
      });
      return true;
    } catch (e) {
      debugPrint('CollabPlaylistService.addSongWithCredit error: $e');
      return false;
    }
  }
}
