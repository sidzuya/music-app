import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/search_results.dart';
import '../../../data/models/social_user_model.dart';
import '../../../data/services/follow_service.dart';
import '../../../data/services/supabase_database_service.dart';
import '../../providers/follow_provider.dart';
import '../../providers/locale_provider.dart';
import '../search/playlist_results_screen.dart';
import 'follow_list_screen.dart';

/// Public profile of *another* user (or self when navigated to via search).
/// Shows avatar, username, follow counts and a follow / unfollow CTA.
class PublicProfileScreen extends StatefulWidget {
  final SocialUser user;
  final FollowService? followService;
  final SupabaseDatabaseService? dbService;

  const PublicProfileScreen({
    super.key,
    required this.user,
    this.followService,
    this.dbService,
  });

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  late final FollowService _service;
  late final SupabaseDatabaseService _dbService;
  FollowCounts _counts = FollowCounts.empty;
  List<PlaylistSummary> _playlists = [];
  bool _loading = true;
  bool _theyFollowMe = false;

  @override
  void initState() {
    super.initState();
    _service = widget.followService ?? FollowService();
    _dbService = widget.dbService ?? SupabaseDatabaseService();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final results = await Future.wait([
      _service.getCounts(widget.user.id),
      if (myId != null) _service.followingIds(widget.user.id) else Future.value(<String>{}),
      _loadUserPlaylists(),
    ]);
    if (!mounted) return;
    setState(() {
      _counts = results[0] as FollowCounts;
      final theirFollowing = results[1] as Set<String>;
      _theyFollowMe = myId != null && theirFollowing.contains(myId);
      _playlists = results[2] as List<PlaylistSummary>;
      _loading = false;
    });
  }

  Future<List<PlaylistSummary>> _loadUserPlaylists() async {
    try {
      final rows = await _dbService.getUserPlaylists(widget.user.id);
      return rows.map(PlaylistSummary.fromMap).toList();
    } catch (e) {
      debugPrint('PublicProfileScreen: error loading playlists: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final isSelf = myId != null && myId == widget.user.id;
    final isPrivateProfile = !isSelf && !widget.user.profileVisible;

    if (isPrivateProfile) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          title: Text(widget.user.username),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              CircleAvatar(
                radius: 56,
                backgroundColor: Theme.of(context).colorScheme.primary,
                backgroundImage: (widget.user.profileImage ?? '').isNotEmpty
                    ? NetworkImage(widget.user.profileImage!)
                    : null,
                child: (widget.user.profileImage ?? '').isEmpty
                    ? Text(
                        widget.user.username.isNotEmpty
                            ? widget.user.username[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                widget.user.username,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.surfaceColor),
                ),
                child: Column(
                  children: [
                    Icon(Icons.lock_outline, size: 48, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 16),
                    const Text(
                      'Этот профиль является приватным',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Пользователь ограничил доступ к своей информации.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      );
    }

    return Consumer2<LocaleProvider, FollowProvider>(
      builder: (context, localeProvider, follow, _) {
        final isFollowing = follow.isFollowing(widget.user.id);
        final isFriend = isFollowing && _theyFollowMe;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            title: Text(widget.user.username),
          ),
          body: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 56,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    backgroundImage: (widget.user.profileImage ?? '').isNotEmpty
                        ? NetworkImage(widget.user.profileImage!)
                        : null,
                    child: (widget.user.profileImage ?? '').isEmpty
                        ? Text(
                            widget.user.username.isNotEmpty
                                ? widget.user.username[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.user.username,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if ((widget.user.email ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.user.email!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ],

                // Bio Section
                if (widget.user.bio != null && widget.user.bio!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      widget.user.bio!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],

                // Social Links Section
                if (widget.user.socialLinks != null) ...[
                  Builder(
                    builder: (context) {
                      final displayLinks = widget.user.socialLinks!
                          .where((l) => l['type'] != 'privacy_settings' && (l['platform'] ?? '').toString().isNotEmpty)
                          .toList();
                      if (displayLinks.isEmpty) return const SizedBox.shrink();
                      
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: displayLinks.map((link) {
                            final platform = link['platform'] ?? 'Link';
                            final url = link['url'] ?? '';
                            return ActionChip(
                              backgroundColor: AppTheme.cardBackground,
                              avatar: const Icon(Icons.link, size: 16, color: Colors.blueAccent),
                              label: Text(
                                platform,
                                style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                              ),
                              onPressed: () async {
                                if (url.isNotEmpty) {
                                  final uri = Uri.parse(url);
                                  try {
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri);
                                    }
                                  } catch (e) {
                                    debugPrint('Error launching url: $e');
                                  }
                                }
                              },
                            );
                          }).toList(),
                        ),
                      );
                    }
                  ),
                ],

                const SizedBox(height: 16),
                if (!isSelf)
                  Center(
                    child: _PrimaryAction(
                      isFollowing: isFollowing,
                      isFriend: isFriend,
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final errorColor =
                            Theme.of(context).colorScheme.error;
                        try {
                          await follow.toggle(widget.user.id);
                          await _load();
                        } catch (e) {
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                e.toString().replaceFirst('Exception: ', ''),
                              ),
                              backgroundColor: errorColor,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                const SizedBox(height: 24),
                // Counts always stay visible. If the user hid their followers
                // list, opening it shows a "list hidden" placeholder inside
                // FollowListScreen instead of removing the numbers here.
                _StatsRow(
                  counts: _counts,
                  loading: _loading,
                  localeProvider: localeProvider,
                  onTap: (initialTab) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FollowListScreen(
                          userId: widget.user.id,
                          username: widget.user.username,
                          initialTab: initialTab,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                if (_playlists.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      localeProvider.getString('playlists'),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._playlists.map((p) => _PlaylistTile(
                    playlist: p,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PlaylistResultsScreen(
                            playlist: p,
                            followService: _service,
                            databaseService: _dbService,
                          ),
                        ),
                      );
                    },
                  )),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  final bool isFollowing;
  final bool isFriend;
  final VoidCallback onPressed;

  const _PrimaryAction({
    required this.isFollowing,
    required this.isFriend,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final color = Theme.of(context).colorScheme.primary;
    final label = isFriend
        ? localeProvider.getString('friends_button')
        : isFollowing
            ? localeProvider.getString('following_button')
            : localeProvider.getString('follow');

    if (isFollowing) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(isFriend ? Icons.people : Icons.check, color: color),
        label: Text(label, style: TextStyle(color: color)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.person_add_alt_1, color: Colors.black),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final FollowCounts counts;
  final bool loading;
  final LocaleProvider localeProvider;
  final void Function(FollowListTab tab) onTap;

  const _StatsRow({
    required this.counts,
    required this.loading,
    required this.localeProvider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat(
            context,
            label: localeProvider.getString('followers'),
            value: counts.followers,
            onTap: () => onTap(FollowListTab.followers),
          ),
          _stat(
            context,
            label: localeProvider.getString('following'),
            value: counts.following,
            onTap: () => onTap(FollowListTab.following),
          ),
          _stat(
            context,
            label: localeProvider.getString('friends'),
            value: counts.friends,
            onTap: () => onTap(FollowListTab.friends),
          ),
        ],
      ),
    );
  }

  Widget _stat(
    BuildContext context, {
    required String label,
    required int value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Text(
              loading ? '…' : value.toString(),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  final PlaylistSummary playlist;
  final VoidCallback onTap;

  const _PlaylistTile({required this.playlist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cover = playlist.coverUrl;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 48,
          height: 48,
          child: cover != null && cover.isNotEmpty
              ? Image.network(cover, fit: BoxFit.cover)
              : Container(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.2),
                  child: Icon(
                    Icons.queue_music,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
        ),
      ),
      title: Text(
        playlist.name,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: playlist.description != null && playlist.description!.isNotEmpty
          ? Text(
              playlist.description!,
              style: const TextStyle(color: AppTheme.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
      onTap: onTap,
    );
  }
}
