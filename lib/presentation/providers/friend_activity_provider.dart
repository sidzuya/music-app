import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/friend_activity_model.dart';
import '../../data/services/friend_activity_service.dart';
import '../../data/services/follow_service.dart';

class FriendActivityProvider with ChangeNotifier {
  final _activityService = FriendActivityService();
  final _followService = FollowService();

  List<FriendActivityModel> _activities = [];
  bool _isLoading = false;
  Timer? _refreshTimer;

  List<FriendActivityModel> get activities => _activities;
  bool get isLoading => _isLoading;

  FriendActivityProvider() {
    // Start auto-refreshing every 5 seconds for faster UI updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      refreshActivities();
    });
    
    // Initial fetch
    refreshActivities();
  }

  Future<void> refreshActivities() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    if (_activities.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      // Get the set of users we are following
      final followingIds = await _followService.followingIds(user.id);
      
      if (followingIds.isNotEmpty) {
        _activities = await _activityService.getFriendsActivity(followingIds);
      } else {
        _activities = [];
      }
    } catch (e) {
      debugPrint('Error refreshing friend activities: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
