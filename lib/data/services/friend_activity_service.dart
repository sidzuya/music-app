import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/friend_activity_model.dart';
import '../models/song_model.dart';
import '../models/social_user_model.dart';

class FriendActivityService {
  final _client = Supabase.instance.client;

  String? get _userId => _client.auth.currentUser?.id;

  /// Updates the current user's activity.
  /// Fails silently if the `user_activity` table does not exist.
  Future<void> updateActivity(SongModel? song, bool isPlaying, {bool isOnline = true}) async {
    final me = _userId;
    if (me == null) return;

    try {
      if (song == null) {
        // If no song is playing, just set is_playing to false
        await _client.from('user_activity').upsert(
          {
            'user_id': me,
            'is_playing': false,
            'is_online': isOnline,
            'updated_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'user_id',
        );
      } else {
        await _client.from('user_activity').upsert(
          {
            'user_id': me,
            'song_title': song.title,
            'song_artist': song.artist,
            'song_album_art': song.albumArt,
            'song_url': song.audioUrl,
            'is_playing': isPlaying,
            'is_online': isOnline,
            'updated_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'user_id',
        );
      }
    } catch (e) {
      debugPrint('FriendActivityService.updateActivity error (maybe table missing?): $e');
    }
  }

  /// Fetches activity for a specific list of user IDs.
  /// Returns empty list if table doesn't exist.
  Future<List<FriendActivityModel>> getFriendsActivity(Set<String> friendIds) async {
    if (friendIds.isEmpty) return [];

    try {
      // Fetch profiles manually FIRST
      final profilesResponse = await _client
          .from('profiles')
          .select()
          .inFilter('id', friendIds.toList());

      final profileMapList = profilesResponse as List<dynamic>;
      if (profileMapList.isEmpty) return [];

      // Fetch user_activity for these friends
      final activityResponse = await _client
          .from('user_activity')
          .select()
          .inFilter('user_id', friendIds.toList());

      final activitiesRaw = activityResponse as List<dynamic>;
      final activityMapById = {
        for (var a in activitiesRaw) a['user_id'] as String: a as Map<String, dynamic>
      };

      final List<FriendActivityModel> activities = [];
      
      for (final profileMap in profileMapList) {
        final userId = profileMap['id'] as String;
        final socialUser = SocialUser.fromMap(Map<String, dynamic>.from(profileMap as Map));
        final activityRow = activityMapById[userId];
        
        if (activityRow != null && socialUser.listeningActivity) {
          // Has activity row and privacy settings permit sharing
          activities.add(FriendActivityModel.fromMap(activityRow, Map<String, dynamic>.from(profileMap as Map)));
        } else {
          // Never listened to anything (no row in user_activity) or privacy settings block sharing
          // We create a dummy activity map with is_playing = false
          activities.add(FriendActivityModel.fromMap({
            'user_id': userId,
            'is_playing': false,
            // Fallback to profile creation/update time for "last seen"
            'updated_at': profileMap['updated_at'] ?? profileMap['created_at'] ?? DateTime.now().toIso8601String(),
          }, Map<String, dynamic>.from(profileMap as Map)));
        }
      }
      
      // Sort: playing first, then by last updated
      activities.sort((a, b) {
        if (a.isPlaying && !b.isPlaying) return -1;
        if (!a.isPlaying && b.isPlaying) return 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
      
      return activities;
    } catch (e) {
      debugPrint('FriendActivityService.getFriendsActivity error: $e');
      return [];
    }
  }
}
