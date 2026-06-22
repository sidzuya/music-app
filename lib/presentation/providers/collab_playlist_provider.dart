import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/collab_playlist_model.dart';
import '../../data/models/song_model.dart';
import '../../data/services/collab_playlist_service.dart';
import '../../data/services/follow_service.dart';

class CollabPlaylistProvider with ChangeNotifier {
  final _service = CollabPlaylistService();
  final _followService = FollowService();
  final _client = Supabase.instance.client;

  List<CollabPlaylistModel> _pendingInvites = [];
  List<Map<String, dynamic>> _myCollabPlaylists = [];
  List<String> _mySharedPlaylistIds = [];
  List<Map<String, dynamic>> _friends = [];
  bool _isLoading = false;
  Timer? _refreshTimer;

  List<CollabPlaylistModel> get pendingInvites => _pendingInvites;
  List<Map<String, dynamic>> get myCollabPlaylists => _myCollabPlaylists;
  List<String> get mySharedPlaylistIds => _mySharedPlaylistIds;
  List<Map<String, dynamic>> get friends => _friends;
  bool get isLoading => _isLoading;
  int get pendingCount => _pendingInvites.length;

  CollabPlaylistProvider() {
    refresh();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      refresh();
    });
  }

  Future<void> refresh() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final results = await Future.wait([
        _service.getPendingInvites(),
        _service.getMyCollabPlaylists(),
        _client
            .from('playlist_collaborators')
            .select('playlist_id')
            .eq('invited_by', user.id)
            .eq('status', 'accepted'),
      ]);
      _pendingInvites = results[0] as List<CollabPlaylistModel>;
      _myCollabPlaylists = results[1] as List<Map<String, dynamic>>;
      _mySharedPlaylistIds = (results[2] as List).map((r) => r['playlist_id'] as String).toList();
      debugPrint('CollabPlaylistProvider: loaded ${_mySharedPlaylistIds.length} shared playlists');
      notifyListeners();
    } catch (e) {
      debugPrint('CollabPlaylistProvider.refresh error: $e');
    }
  }

  Future<void> loadFriends() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final followingIds = await _followService.followingIds(user.id);
      if (followingIds.isNotEmpty) {
        final profiles = await _client
            .from('profiles')
            .select('id, username, profile_image')
            .inFilter('id', followingIds.toList());
        _friends = List<Map<String, dynamic>>.from(profiles);
      } else {
        _friends = [];
      }
    } catch (e) {
      debugPrint('CollabPlaylistProvider.loadFriends error: $e');
      _friends = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> inviteCollaborator({
    required String playlistId,
    required String playlistName,
    required String friendId,
  }) async {
    final result = await _service.inviteCollaborator(
      playlistId: playlistId,
      playlistName: playlistName,
      friendId: friendId,
    );
    return result;
  }

  Future<bool> acceptInvite(String playlistId) async {
    final result = await _service.acceptInvite(playlistId);
    if (result) {
      _pendingInvites.removeWhere((i) => i.playlistId == playlistId);
      notifyListeners();
      await refresh();
    }
    return result;
  }

  Future<bool> declineInvite(String playlistId) async {
    final result = await _service.declineInvite(playlistId);
    if (result) {
      _pendingInvites.removeWhere((i) => i.playlistId == playlistId);
      notifyListeners();
    }
    return result;
  }

  Future<bool> leavePlaylist(String playlistId) async {
    final result = await _service.leavePlaylist(playlistId);
    if (result) {
      _myCollabPlaylists.removeWhere((p) => p['id'] == playlistId);
      notifyListeners();
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> getCollaborators(String playlistId) async {
    return _service.getCollaborators(playlistId);
  }

  Future<bool> isCollaborator(String playlistId) async {
    return _service.isCollaborator(playlistId);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
  Future<bool> addSong(String playlistId, SongModel song) async {
    final success = await _service.addSongWithCredit(playlistId, song);
    if (success) {
      notifyListeners();
    }
    return success;
  }

  /// Delete a collaborative playlist (only the owner should call this).
  /// Removes collaborators, songs, and the playlist itself from Supabase.
  Future<bool> deleteCollabPlaylist(String playlistId) async {
    try {
      // Delete collaborators
      await _client
          .from('playlist_collaborators')
          .delete()
          .eq('playlist_id', playlistId);

      // Delete songs
      await _client
          .from('playlist_songs')
          .delete()
          .eq('playlist_id', playlistId);

      // Delete the playlist itself
      await _client
          .from('playlists')
          .delete()
          .eq('id', playlistId);

      // Update local state
      _myCollabPlaylists.removeWhere((p) => p['id'] == playlistId);
      _mySharedPlaylistIds.remove(playlistId);
      notifyListeners();

      debugPrint('CollabPlaylistProvider: Deleted collab playlist $playlistId');
      return true;
    } catch (e) {
      debugPrint('CollabPlaylistProvider.deleteCollabPlaylist error: $e');
      return false;
    }
  }
}
