import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/follow_service.dart';
import '../../providers/notification_provider.dart';
import '../../providers/collab_playlist_provider.dart';
import '../social/public_profile_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotificationProvider>().service.loadNotifications();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: const Text(
          'Уведомления',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, child) {
              if (provider.unreadCount == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed: () => provider.markAllAsRead(),
                child: const Text(
                  'Прочитать все',
                  style: TextStyle(color: AppTheme.primaryGreen, fontSize: 13),
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<SharedPreferences>(
        future: SharedPreferences.getInstance(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final prefs = snapshot.data!;
          final email = Supabase.instance.client.auth.currentUser?.email ?? 'anonymous';
          final playlistsEnabled = prefs.getBool('notif_playlists_enabled_$email') ?? true;

          return Consumer2<NotificationProvider, CollabPlaylistProvider>(
            builder: (context, notifProvider, collabProvider, child) {
              // Merge notifications with pending invites (if enabled)
              final pendingInvites = playlistsEnabled
                  ? collabProvider.pendingInvites.map((invite) {
                      return NotificationModel(
                        id: invite.playlistId, // Use playlistId as id for uniqueness
                        userId: invite.userId,
                        type: 'collab_invite',
                        title: '${invite.invitedByUsername ?? 'Пользователь'} приглашает вас',
                        message: 'Совместный плейлист: "${invite.playlistName ?? 'Без названия'}"',
                        data: {
                          'playlist_id': invite.playlistId,
                          'playlist_name': invite.playlistName,
                        },
                        read: false,
                        createdAt: invite.createdAt,
                      );
                    }).toList()
                  : <NotificationModel>[];

              // Filter out duplicate invites if they already exist in notifications
              final existingCollabPlaylistIds = notifProvider.notifications
                  .where((n) => n.type == 'collab_invite')
                  .map((n) => n.data?['playlist_id'] as String?)
                  .where((id) => id != null)
                  .toSet();

              final extraInvites = pendingInvites
                  .where((invite) => !existingCollabPlaylistIds.contains(invite.data?['playlist_id']))
                  .toList();

              final allNotifications = [...notifProvider.notifications, ...extraInvites];
              // Sort descending by date
              allNotifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

              return RefreshIndicator(
                onRefresh: () => notifProvider.service.loadNotifications(),
                child: allNotifications.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.notifications_none, size: 72, color: AppTheme.textTertiary),
                                const SizedBox(height: 16),
                                const Text(
                                  'Нет уведомлений',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(12),
                        itemCount: allNotifications.length,
                        itemBuilder: (context, index) {
                          final notif = allNotifications[index];
                  final isCollab = notif.type == 'collab_invite';
                  final isUnread = !notif.read;

                  return GestureDetector(
                    onTap: () async {
                      notifProvider.markAsRead(notif.id);
                      
                      // Custom navigation action for followers
                      if (notif.type == 'new_follower') {
                        final followerId = notif.data?['follower_id'] as String?;
                        if (followerId != null && context.mounted) {
                          // Show loading indicator
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => const Center(child: CircularProgressIndicator()),
                          );
                          
                          try {
                            final profile = await FollowService().getProfile(followerId);
                            if (context.mounted) {
                              Navigator.pop(context); // Dismiss loading dialog
                              if (profile != null) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PublicProfileScreen(user: profile),
                                  ),
                                );
                              }
                            }
                          } catch (_) {
                            if (context.mounted) Navigator.pop(context);
                          }
                        }
                      }
                    },
                    child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isUnread
                        ? AppTheme.primaryGreen.withValues(alpha: 0.07)
                        : AppTheme.cardBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isUnread
                          ? AppTheme.primaryGreen.withValues(alpha: 0.3)
                          : Colors.transparent,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _getColor(notif.type).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getIcon(notif.type),
                              color: _getColor(notif.type),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notif.title,
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 14,
                                  ),
                                ),
                                if (notif.message != null && notif.message!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    notif.message!,
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppTheme.primaryGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),

                      // Collab invite actions
                      if (isCollab && isUnread) ...[
                        const SizedBox(height: 12),
                        _CollabInviteActions(
                          notification: notif,
                          onAccept: () async {
                            final playlistId = notif.data?['playlist_id'] as String?;
                            if (playlistId != null) {
                              final ok = await collabProvider.acceptInvite(playlistId);
                              if (ok && context.mounted) {
                                notifProvider.markAsRead(notif.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('✅ Вы приняли приглашение! Плейлист появился в вашей библиотеке.'),
                                    backgroundColor: AppTheme.primaryGreen,
                                  ),
                                );
                              }
                            }
                          },
                          onDecline: () async {
                            final playlistId = notif.data?['playlist_id'] as String?;
                            if (playlistId != null) {
                              await collabProvider.declineInvite(playlistId);
                              if (context.mounted) {
                                notifProvider.markAsRead(notif.id);
                              }
                            }
                          },
                        ),
                      ],

                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          _formatTime(notif.createdAt),
                          style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  },
),
);
}

  Color _getColor(String type) {
    switch (type) {
      case 'collab_invite':
        return AppTheme.primaryGreen;
      case 'artist_application_approved':
      case 'song_approved':
        return Colors.green;
      case 'artist_application_rejected':
      case 'song_rejected':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'collab_invite':
        return Icons.people_outline;
      case 'artist_application_approved':
      case 'song_approved':
        return Icons.check_circle_outline;
      case 'artist_application_rejected':
      case 'song_rejected':
        return Icons.cancel_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин. назад';
    if (diff.inHours < 24) return '${diff.inHours} ч. назад';
    return '${diff.inDays} дн. назад';
  }
}

class _CollabInviteActions extends StatefulWidget {
  final NotificationModel notification;
  final Future<void> Function() onAccept;
  final Future<void> Function() onDecline;

  const _CollabInviteActions({
    required this.notification,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<_CollabInviteActions> createState() => _CollabInviteActionsState();
}

class _CollabInviteActionsState extends State<_CollabInviteActions> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading
                ? null
                : () async {
                    setState(() => _isLoading = true);
                    await widget.onDecline();
                  },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              side: const BorderSide(color: AppTheme.textTertiary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            child: const Text('Отклонить', style: TextStyle(fontSize: 13)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading
                ? null
                : () async {
                    setState(() => _isLoading = true);
                    await widget.onAccept();
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Text('Принять', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
