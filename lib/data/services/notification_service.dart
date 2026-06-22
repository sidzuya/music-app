import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Model for a notification
class NotificationModel {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String? message;
  final Map<String, dynamic>? data;
  final bool read;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    this.message,
    this.data,
    required this.read,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      type: map['type'] as String,
      title: map['title'] as String,
      message: map['message'] as String?,
      data: map['data'] as Map<String, dynamic>?,
      read: map['read'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'title': title,
      'message': message,
      'data': data,
      'read': read,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Service for managing notifications
class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  @visibleForTesting
  NotificationService.forTesting();

  static SupabaseClient get _client => Supabase.instance.client;

  final List<NotificationModel> _notifications = [];
  StreamSubscription? _subscription;
  bool _pushEnabled = true;
  bool _initialized = false;

  bool get isPushEnabled => _pushEnabled;
  bool get isInitialized => _initialized;

  List<NotificationModel> get notifications => _notifications;
  List<NotificationModel> get unreadNotifications =>
      _notifications.where((n) => !n.read).toList();

  int get unreadCount => unreadNotifications.length;

  Future<void> initialize() async {
    _initialized = false;
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();
      final email = user.email ?? 'anonymous';
      final pushEnabled = prefs.getBool('notif_push_enabled_$email') ?? true;
      _pushEnabled = pushEnabled;

      // If push is disabled, clear notifications and unsubscribe
      if (!pushEnabled) {
        _subscription?.cancel();
        _notifications.clear();
        notifyListeners();
        return;
      }

      // Load initial notifications
      await loadNotifications();

      // Listen for new notifications in real-time using Supabase Realtime
      _subscription?.cancel(); // Cancel any existing subscription first
      _subscription = _client
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', user.id)
          .listen((List<Map<String, dynamic>> data) async {
            debugPrint('Notifications stream updated: ${data.length} items');
            final p = await SharedPreferences.getInstance();
            final pushEnabled = p.getBool('notif_push_enabled_$email') ?? true;
            if (!pushEnabled) {
              _notifications.clear();
              notifyListeners();
              return;
            }
            final playlistsEnabled = p.getBool('notif_playlists_enabled_$email') ?? true;
            final socialEnabled = p.getBool('notif_social_enabled_$email') ?? false;

            for (final item in data) {
              final notification = NotificationModel.fromMap(item);
              
              // Filter based on preferences
              if (notification.type == 'collab_invite' && !playlistsEnabled) continue;
              if (notification.type == 'new_follower' && !socialEnabled) continue;

              // Add if not already in list
              if (!_notifications.any((n) => n.id == notification.id)) {
                _notifications.insert(0, notification);
              }
            }
            notifyListeners();
          }, onError: (error) {
          });
      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('NotificationService initialization failed: $e');
    }
  }

  /// Load all notifications from database
  Future<void> loadNotifications() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();
      final email = user.email ?? 'anonymous';
      
      final pushEnabled = prefs.getBool('notif_push_enabled_$email') ?? true;
      _notifications.clear();
      if (!pushEnabled) {
        notifyListeners();
        return;
      }

      final playlistsEnabled = prefs.getBool('notif_playlists_enabled_$email') ?? true;
      final socialEnabled = prefs.getBool('notif_social_enabled_$email') ?? false;

      final rows = await _client
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      for (final row in rows) {
        final notification = NotificationModel.fromMap(
            Map<String, dynamic>.from(row as Map));
        
        // Filter based on settings
        if (notification.type == 'collab_invite' && !playlistsEnabled) continue;
        if (notification.type == 'new_follower' && !socialEnabled) continue;

        _notifications.add(notification);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }
  }

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _client.rpc('mark_notification_as_read',
          params: {'notification_id': notificationId});

      // Update local state
      final index =
          _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = NotificationModel(
          id: _notifications[index].id,
          userId: _notifications[index].userId,
          type: _notifications[index].type,
          title: _notifications[index].title,
          message: _notifications[index].message,
          data: _notifications[index].data,
          read: true,
          createdAt: _notifications[index].createdAt,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      for (final notif in unreadNotifications) {
        await markAsRead(notif.id);
      }
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  /// Dispose and clean up
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  /// Cleanup (call manually if needed)
  void cleanup() {
    _subscription?.cancel();
    _subscription = null;
    _notifications.clear();
    _initialized = false;
    notifyListeners();
  }
}
