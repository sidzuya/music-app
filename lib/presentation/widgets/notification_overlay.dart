import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/services/notification_service.dart';
import '../providers/notification_provider.dart';
import '../providers/auth_provider.dart';

/// Model for tracking notification display queue
class _NotificationDisplayItem {
  final String id;
  final NotificationModel notification;

  _NotificationDisplayItem({
    required this.id,
    required this.notification,
  });
}

/// Widget that displays notifications as they arrive
class NotificationOverlay extends StatefulWidget {
  final Widget child;
  final bool showAllUnreadInitially;

  const NotificationOverlay({
    required this.child,
    this.showAllUnreadInitially = false,
    super.key,
  });

  @override
  State<NotificationOverlay> createState() => _NotificationOverlayState();
}

class _NotificationOverlayState extends State<NotificationOverlay> {
  final List<_NotificationDisplayItem> _displayQueue = [];
  NotificationModel? _currentNotification;
  final Set<String> _initialNotificationIds = {};
  bool _isFirstLoad = true;

  NotificationProvider? _notificationProvider;
  AuthProvider? _authProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          _notificationProvider = context.read<NotificationProvider>();
        } catch (_) {}
        try {
          _authProvider = context.read<AuthProvider>();
        } catch (_) {}

        if (_notificationProvider != null) {
          if (!widget.showAllUnreadInitially) {
            for (final notif in _notificationProvider!.unreadNotifications) {
              _initialNotificationIds.add(notif.id);
            }
          }
          _notificationProvider!.addListener(_onNotificationsChanged);
        }
        _authProvider?.addListener(_onAuthChanged);
      }
    });
  }

  @override
  void dispose() {
    _notificationProvider?.removeListener(_onNotificationsChanged);
    _authProvider?.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted || _authProvider == null) return;
    if (!_authProvider!.isLoggedIn) {
      _displayQueue.clear();
      _initialNotificationIds.clear();
      _isFirstLoad = true;
      if (_currentNotification != null) {
        setState(() {
          _currentNotification = null;
        });
      }
    } else {
      if (_notificationProvider != null) {
        for (final notif in _notificationProvider!.unreadNotifications) {
          _initialNotificationIds.add(notif.id);
        }
      }
    }
  }

  void _onNotificationsChanged() {
    if (_notificationProvider == null) return;

    if (_authProvider != null && !_authProvider!.isLoggedIn) {
      _displayQueue.clear();
      if (_currentNotification != null) {
        setState(() {
          _currentNotification = null;
        });
      }
      return;
    }

    final provider = _notificationProvider!;
    // If push notifications are disabled, clear queue and dismiss any active overlay
    if (!provider.service.isPushEnabled) {
      _displayQueue.clear();
      setState(() {
        _currentNotification = null;
      });
      return;
    }

    if (_isFirstLoad && provider.service.isInitialized) {
      _isFirstLoad = false;
      if (!widget.showAllUnreadInitially) {
        for (final notif in provider.unreadNotifications) {
          _initialNotificationIds.add(notif.id);
        }
      }
    }

    final now = DateTime.now();
    // Show only new unread notifications
    for (final notif in provider.unreadNotifications) {
      if (_initialNotificationIds.contains(notif.id)) {
        continue;
      }
      // Skip old notifications (> 10 minutes) to avoid popping them up on startup / slow load / clock skew
      final age = now.difference(notif.createdAt.toLocal()).abs();
      if (age.inMinutes >= 10) {
        continue;
      }

      if (!_displayQueue.any((item) => item.id == notif.id) &&
          _currentNotification?.id != notif.id) {
        _initialNotificationIds.add(notif.id); // Mark it as processed immediately to prevent repeating alerts
        _displayQueue.add(_NotificationDisplayItem(
          id: notif.id,
          notification: notif,
        ));
      }
    }
    _showNext();
  }

  void _showNext() {
    if (_displayQueue.isEmpty || _currentNotification != null) {
      return;
    }

    final item = _displayQueue.removeAt(0);
    setState(() {
      _currentNotification = item.notification;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_currentNotification != null)
          _NotificationCard(
            key: ValueKey(_currentNotification!.id),
            notification: _currentNotification!,
            onDismiss: () {
              setState(() {
                _currentNotification = null;
              });
              _showNext();
            },
          ),
      ],
    );
  }
}

/// Individual notification card that appears at the top
class _NotificationCard extends StatefulWidget {
  final NotificationModel notification;
  final VoidCallback onDismiss;

  const _NotificationCard({
    required this.notification,
    required this.onDismiss,
    super.key,
  });

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    // Auto-dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _dismissWithAnimation();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismissWithAnimation() async {
    await _controller.reverse();
    if (mounted) {
      widget.onDismiss();
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'artist_application_approved':
        return Colors.green;
      case 'artist_application_rejected':
        return Colors.orange;
      case 'song_approved':
        return Colors.green;
      case 'song_rejected':
        return Colors.orange;
      case 'new_follower':
        return Colors.deepPurple;
      case 'collab_invite':
        return Colors.blue;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'artist_application_approved':
      case 'song_approved':
        return Icons.check_circle;
      case 'artist_application_rejected':
      case 'song_rejected':
        return Icons.cancel;
      case 'new_follower':
        return Icons.person_add;
      case 'collab_invite':
        return Icons.playlist_add;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Material(
              type: MaterialType.transparency,
              child: GestureDetector(
                onTap: _dismissWithAnimation,
                child: Card(
                  elevation: 8,
                  color: _getColorForType(widget.notification.type),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _getIconForType(widget.notification.type),
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.notification.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (widget.notification.message != null &&
                                  widget.notification.message!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    widget.notification.message!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _dismissWithAnimation,
                          child: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Optional: A badge widget that shows unread notification count
class NotificationBadge extends StatelessWidget {
  final Widget icon;
  final VoidCallback onTap;

  const NotificationBadge({
    required this.icon,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        final unreadCount = provider.unreadCount;
        return Stack(
          children: [
            IconButton(
              icon: icon,
              onPressed: onTap,
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
