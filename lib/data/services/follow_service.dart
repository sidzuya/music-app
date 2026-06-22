import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/social_user_model.dart';

/// Service for the social graph (follow / unfollow / followers / friends).
///
/// All methods are defensive: if the `follows` table does not exist yet, or
/// RLS prevents reading, they return safe defaults instead of throwing — so
/// the UI keeps working until the migration in `supabase/follows.sql` is
/// applied.
class FollowService {
  static FollowService _instance = FollowService._internal();
  factory FollowService() => _instance;
  FollowService._internal();

  @visibleForTesting
  static set instance(FollowService value) => _instance = value;

  @visibleForTesting
  FollowService.forTesting();

  SupabaseClient get _client => Supabase.instance.client;
  String? get _currentUserId => _client.auth.currentUser?.id;

  // ─── Mutations ────────────────────────────────────────────────────────────

  Future<void> follow(String targetUserId) async {
    final me = _currentUserId;
    if (me == null) throw Exception('Not authenticated');
    if (me == targetUserId) {
      throw Exception('Нельзя подписаться на самого себя');
    }
    await _client.from('follows').upsert(
      {
        'follower_id': me,
        'followee_id': targetUserId,
      },
      onConflict: 'follower_id,followee_id',
    );

    // Send in-app follower notification to targetUserId, ignore RLS/DB errors if it fails
    try {
      final myProfile = await getProfile(me);
      final myUsername = myProfile?.username ?? 'Кто-то';
      await _client.from('notifications').insert({
        'user_id': targetUserId,
        'type': 'new_follower',
        'title': 'Новый подписчик!',
        'message': 'Пользователь $myUsername подписался на вас',
        'data': {
          'follower_id': me,
          'follower_username': myUsername,
          'follower_avatar_url': myProfile?.profileImage,
        },
      });
    } catch (e) {
      debugPrint('FollowService.follow: Error sending notification: $e');
    }
  }

  Future<void> unfollow(String targetUserId) async {
    final me = _currentUserId;
    if (me == null) throw Exception('Not authenticated');
    await _client
        .from('follows')
        .delete()
        .eq('follower_id', me)
        .eq('followee_id', targetUserId);
  }

  // ─── Reads ────────────────────────────────────────────────────────────────

  /// True if the current user follows [targetUserId].
  Future<bool> isFollowing(String targetUserId) async {
    final me = _currentUserId;
    if (me == null || me == targetUserId) return false;
    try {
      final row = await _client
          .from('follows')
          .select('follower_id')
          .eq('follower_id', me)
          .eq('followee_id', targetUserId)
          .maybeSingle();
      return row != null;
    } catch (e) {
      debugPrint('FollowService.isFollowing error: $e');
      return false;
    }
  }

  /// IDs the user follows.
  Future<Set<String>> followingIds(String userId) async {
    try {
      final rows = await _client
          .from('follows')
          .select('followee_id')
          .eq('follower_id', userId);
      return rows
          .map<String>((r) => r['followee_id'] as String)
          .toSet();
    } catch (e) {
      debugPrint('FollowService.followingIds error: $e');
      return <String>{};
    }
  }

  /// IDs that follow the user.
  Future<Set<String>> followerIds(String userId) async {
    try {
      final rows = await _client
          .from('follows')
          .select('follower_id')
          .eq('followee_id', userId);
      return rows
          .map<String>((r) => r['follower_id'] as String)
          .toSet();
    } catch (e) {
      debugPrint('FollowService.followerIds error: $e');
      return <String>{};
    }
  }

  /// Get a single profile by id.
  Future<SocialUser?> getProfile(String userId) async {
    try {
      final row = await _client
          .from('profiles')
          .select('id, username, email, profile_image, social_links')
          .eq('id', userId)
          .maybeSingle();
      if (row == null) return null;
      return SocialUser.fromMap(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      debugPrint('FollowService.getProfile error: $e');
      return null;
    }
  }

  /// Resolve a list of profile rows by id.
  Future<List<SocialUser>> _profilesByIds(Set<String> ids) async {
    if (ids.isEmpty) return const [];
    try {
      final rows = await _client
          .from('profiles')
          .select()
          .inFilter('id', ids.toList());
      return rows
          .map<SocialUser>(
            (r) => SocialUser.fromMap(Map<String, dynamic>.from(r as Map)),
          )
          .toList();
    } catch (e) {
      debugPrint('FollowService._profilesByIds error: $e');
      return const [];
    }
  }

  Future<List<SocialUser>> getFollowers(String userId) async {
    final ids = await followerIds(userId);
    return _profilesByIds(ids);
  }

  Future<List<SocialUser>> getFollowing(String userId) async {
    final ids = await followingIds(userId);
    return _profilesByIds(ids);
  }

  /// Friends = mutual follows (you follow them AND they follow you).
  Future<List<SocialUser>> getFriends(String userId) async {
    final results = await Future.wait([
      followingIds(userId),
      followerIds(userId),
    ]);
    final mutual = results[0].intersection(results[1]);
    return _profilesByIds(mutual);
  }

  /// Counts for the profile header.
  Future<FollowCounts> getCounts(String userId) async {
    final results = await Future.wait([
      followingIds(userId),
      followerIds(userId),
    ]);
    final following = results[0];
    final followers = results[1];
    return FollowCounts(
      followers: followers.length,
      following: following.length,
      friends: following.intersection(followers).length,
    );
  }

  /// Search public profiles by username/email substring.
  Future<List<SocialUser>> searchUsers(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final pattern = '%${trimmed.replaceAll('%', r'\%')}%';
    try {
      final rows = await _client
          .from('profiles')
          .select()
          .or('username.ilike.$pattern,email.ilike.$pattern')
          .limit(40);
      final me = _currentUserId;
      final users = rows
          .map<SocialUser>(
            (r) => SocialUser.fromMap(Map<String, dynamic>.from(r as Map)),
          )
          .where((u) => u.id.isNotEmpty && u.id != me && u.profileVisible)
          .toList();
      return users;
    } catch (e) {
      debugPrint('FollowService.searchUsers error: $e');
      return const [];
    }
  }
}

class FollowCounts {
  final int followers;
  final int following;
  final int friends;

  const FollowCounts({
    required this.followers,
    required this.following,
    required this.friends,
  });

  static const empty = FollowCounts(followers: 0, following: 0, friends: 0);
}
