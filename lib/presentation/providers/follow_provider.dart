import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/services/follow_service.dart';

/// Reactive cache around [FollowService] for the *current* user. Tracks the
/// follow-counts and the set of users the current user follows so that any
/// `Follow / Unfollow` button across the app reflects the latest state.
class FollowProvider with ChangeNotifier {
  final FollowService _service = FollowService();

  FollowCounts _counts = FollowCounts.empty;
  Set<String> _followingIds = <String>{};
  bool _isLoading = false;

  FollowCounts get counts => _counts;
  Set<String> get followingIds => _followingIds;
  bool get isLoading => _isLoading;

  bool isFollowing(String userId) => _followingIds.contains(userId);

  String? get _myId => Supabase.instance.client.auth.currentUser?.id;

  /// Load counts + following set for the current user.
  Future<void> refresh() async {
    final me = _myId;
    if (me == null) {
      _counts = FollowCounts.empty;
      _followingIds = <String>{};
      notifyListeners();
      return;
    }
    _isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _service.getCounts(me),
        _service.followingIds(me),
      ]);
      _counts = results[0] as FollowCounts;
      _followingIds = results[1] as Set<String>;
    } catch (e) {
      debugPrint('FollowProvider.refresh error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> follow(String userId) async {
    final me = _myId;
    if (me == null || me == userId) return;
    // Optimistic update.
    final added = _followingIds.add(userId);
    if (added) {
      _counts = FollowCounts(
        followers: _counts.followers,
        following: _counts.following + 1,
        friends: _counts.friends,
      );
      notifyListeners();
    }
    try {
      await _service.follow(userId);
      // Friends count may have changed (if they follow us back). Re-sync.
      await refresh();
    } catch (e) {
      debugPrint('FollowProvider.follow error: $e');
      // Roll back optimistic state.
      _followingIds.remove(userId);
      await refresh();
      rethrow;
    }
  }

  Future<void> unfollow(String userId) async {
    final me = _myId;
    if (me == null) return;
    final removed = _followingIds.remove(userId);
    if (removed) {
      _counts = FollowCounts(
        followers: _counts.followers,
        following: _counts.following - 1 < 0 ? 0 : _counts.following - 1,
        friends: _counts.friends,
      );
      notifyListeners();
    }
    try {
      await _service.unfollow(userId);
      await refresh();
    } catch (e) {
      debugPrint('FollowProvider.unfollow error: $e');
      _followingIds.add(userId);
      await refresh();
      rethrow;
    }
  }

  Future<void> toggle(String userId) async {
    if (isFollowing(userId)) {
      await unfollow(userId);
    } else {
      await follow(userId);
    }
  }
}
