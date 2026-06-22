import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/collab_playlist_provider.dart';

class CollabInviteScreen extends StatefulWidget {
  final String playlistId;
  final String playlistName;

  const CollabInviteScreen({
    super.key,
    required this.playlistId,
    required this.playlistName,
  });

  @override
  State<CollabInviteScreen> createState() => _CollabInviteScreenState();
}

class _CollabInviteScreenState extends State<CollabInviteScreen> {
  final Set<String> _invitedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CollabPlaylistProvider>().loadFriends();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: const Text(
          'Пригласить друга',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<CollabPlaylistProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGreen),
            );
          }

          if (provider.friends.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_outline, size: 72, color: AppTheme.textTertiary),
                  const SizedBox(height: 16),
                  const Text(
                    'Нет подписок',
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Подпишитесь на пользователей,\nчтобы пригласить их в плейлист',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Плейлист: "${widget.playlistName}"',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: provider.friends.length,
                  itemBuilder: (context, index) {
                    final friend = provider.friends[index];
                    final friendId = friend['id'] as String;
                    final username = friend['username'] as String? ?? 'Пользователь';
                    final avatarUrl = friend['profile_image'] as String?;
                    final isInvited = _invitedIds.contains(friendId);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null
                            ? Text(
                                username[0].toUpperCase(),
                                style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                      title: Text(
                        username,
                        style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                      ),
                      trailing: isInvited
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.textTertiary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                '✓ Отправлено',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              ),
                            )
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryGreen,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              onPressed: () async {
                                final success = await provider.inviteCollaborator(
                                  playlistId: widget.playlistId,
                                  playlistName: widget.playlistName,
                                  friendId: friendId,
                                );
                                if (success && mounted) {
                                  setState(() {
                                    _invitedIds.add(friendId);
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Приглашение отправлено $username!'),
                                      backgroundColor: AppTheme.primaryGreen,
                                    ),
                                  );
                                }
                              },
                              child: const Text('Пригласить', style: TextStyle(fontSize: 13)),
                            ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
