import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_role.dart';
import '../../../data/services/admin/admin_access_service.dart';
import '../../../data/services/role_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/follow_provider.dart';
import '../../providers/locale_provider.dart';
import '../admin/admin_panel_screen.dart';
import '../artist/artist_application_screen.dart';
import '../artist/artist_studio_screen.dart';
import '../moderator/moderator_panel_screen.dart';
import '../auth/login_screen.dart';
import '../settings/account_settings_screen.dart';
import '../settings/notifications_settings_screen.dart';
import '../settings/display_settings_screen.dart';
import '../settings/help_support_screen.dart';
import '../social/follow_list_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver {
  Timer? _rolePoll;
  UserRole? _lastRole;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    RoleService.invalidate();
    _refreshRole();
    // Periodically re-check role from server so role changes made by an
    // admin on another device propagate without a manual reload.
    _rolePoll = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _refreshRole(),
    );
  }

  @override
  void dispose() {
    _rolePoll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshRole();
    }
  }

  Future<void> _refreshRole() async {
    final fresh = await RoleService.currentRole(forceRefresh: true);
    if (!mounted) return;
    if (fresh != _lastRole) {
      setState(() => _lastRole = fresh);
    }
  }

  Future<void> _manualRefresh() async {
    RoleService.invalidate();
    await _refreshRole();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Consumer2<AuthProvider, LocaleProvider>(
          builder: (context, authProvider, localeProvider, child) {
            final user = authProvider.currentUser;

            return RefreshIndicator(
              onRefresh: _manualRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Profile Header
                    _buildProfileHeader(
                      context,
                      user?.username ?? 'User',
                      user?.email ?? '',
                      localeProvider,
                    ),
                    const SizedBox(height: 32),

                    // Stats
                    _buildStatsSection(context, localeProvider),
                    const SizedBox(height: 32),

                    // Settings Options
                    _buildSettingsSection(context, authProvider, localeProvider),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
    BuildContext context,
    String username,
    String email,
    LocaleProvider localeProvider,
  ) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.currentUser;
        final displayUsername = user?.username ?? username;
        final profileImage = user?.profileImage;

        return Column(
          children: [
            // Profile Picture
            CircleAvatar(
              radius: 60,
              backgroundColor: Theme.of(context).colorScheme.primary,
              backgroundImage: profileImage != null && profileImage.isNotEmpty
                  ? NetworkImage(profileImage)
                  : null,
              child: profileImage == null || profileImage.isEmpty
                  ? Text(
                      displayUsername.isNotEmpty
                          ? displayUsername[0].toUpperCase()
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

            // Username
            Text(
              displayUsername,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),

            // Email
            Text(
              email,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),

            // Edit Profile button
            OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EditProfileScreen(),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Theme.of(context).colorScheme.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                localeProvider.getString('edit_profile'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            
            // Bio Section
            if (user?.bio != null && user!.bio!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  user.bio!,
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
            if (user?.socialLinks != null) ...[
              Builder(
                builder: (context) {
                  final displayLinks = user!.socialLinks!
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
          ],
        );
      },
    );
  }

  Widget _buildStatsSection(
    BuildContext context,
    LocaleProvider localeProvider,
  ) {
    return Consumer<FollowProvider>(
      builder: (context, follow, _) {
        final counts = follow.counts;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                context,
                label: localeProvider.getString('followers'),
                value: counts.followers,
                onTap: () => _openFollowList(context, FollowListTab.followers),
              ),
              _buildStatItem(
                context,
                label: localeProvider.getString('following'),
                value: counts.following,
                onTap: () => _openFollowList(context, FollowListTab.following),
              ),
              _buildStatItem(
                context,
                label: localeProvider.getString('friends'),
                value: counts.friends,
                onTap: () => _openFollowList(context, FollowListTab.friends),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openFollowList(BuildContext context, FollowListTab tab) {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final username =
        Provider.of<AuthProvider>(
          context,
          listen: false,
        ).currentUser?.username ??
        'User';
    if (myId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FollowListScreen(userId: myId, username: username, initialTab: tab),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required String label,
    required int value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection(
    BuildContext context,
    AuthProvider authProvider,
    LocaleProvider localeProvider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localeProvider.getString('settings'),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onBackground,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        _buildSettingsItem(
          context: context,
          icon: Icons.person_outline,
          title: localeProvider.getString('account'),
          subtitle: localeProvider.getString('account_subtitle'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AccountSettingsScreen(),
              ),
            );
          },
        ),
        _buildSettingsItem(
          context: context,
          icon: Icons.notifications_outlined,
          title: localeProvider.getString('notifications'),
          subtitle: localeProvider.getString('notifications_subtitle'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NotificationsSettingsScreen(),
              ),
            );
          },
        ),
        _buildSettingsItem(
          context: context,
          icon: Icons.palette_outlined,
          title: localeProvider.getString('display'),
          subtitle: localeProvider.getString('display_subtitle'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DisplaySettingsScreen(),
              ),
            );
          },
        ),
        _buildRoleAwareItems(context, localeProvider),
        _buildSettingsItem(
          context: context,
          icon: Icons.help_outline,
          title: localeProvider.getString('help_support'),
          subtitle: localeProvider.getString('help_support_subtitle'),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
          ),
        ),
        _buildSettingsItem(
          context: context,
          icon: Icons.info_outline,
          title: localeProvider.getString('about_app'),
          subtitle: localeProvider.getString('about_app_subtitle'),
          onTap: () => _showAbout(context, localeProvider),
        ),

        const SizedBox(height: 24),

        // Logout Button
        ListTile(
          leading: const Icon(Icons.logout, color: AppTheme.errorColor),
          title: Text(
            localeProvider.getString('logout'),
            style: const TextStyle(
              color: AppTheme.errorColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          onTap: () => _showLogoutDialog(context, authProvider, localeProvider),
        ),
      ],
    );
  }

  Widget _buildSettingsItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).textTheme.bodyMedium?.color),
      title: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onBackground,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyMedium?.color,
          fontSize: 12,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Theme.of(context).textTheme.bodyMedium?.color,
      ),
      onTap: onTap,
    );
  }

  Widget _buildRoleAwareItems(
      BuildContext context, LocaleProvider localeProvider) {
    final role = _lastRole ?? UserRole.user;
    final items = <Widget>[];
    {
        if (role == UserRole.user) {
          items.add(_buildSettingsItem(
            context: context,
            icon: Icons.mic_external_on_outlined,
            title: 'Стать исполнителем',
            subtitle: 'Подать заявку модератору',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ArtistApplicationScreen(),
              ),
            ),
          ));
        }
        if (role.isArtist) {
          items.add(_buildSettingsItem(
            context: context,
            icon: Icons.library_music_outlined,
            title: 'Студия исполнителя',
            subtitle: 'Загрузка и управление вашими треками',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ArtistStudioScreen()),
            ),
          ));
        }
        if (role.isModerator) {
          items.add(_buildSettingsItem(
            context: context,
            icon: Icons.verified_user_outlined,
            title: 'Панель модератора',
            subtitle: 'Заявки, треки и жалобы',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ModeratorPanelScreen()),
            ),
          ));
        }
        if (role.isAdmin) {
          items.add(_buildSettingsItem(
            context: context,
            icon: Icons.admin_panel_settings_outlined,
            title: localeProvider.getString('admin_panel'),
            subtitle: localeProvider.getString('admin_panel_subtitle'),
            onTap: () => _openAdminPanel(context, localeProvider),
          ));
        }
    }
    return Column(children: items);
  }

  Future<void> _openAdminPanel(
    BuildContext context,
    LocaleProvider localeProvider,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(localeProvider.getString('checking_admin_access')),
      ),
    );

    final isAdmin = await AdminAccessService.isCurrentUserAdmin();
    if (!context.mounted) return;
    messenger.hideCurrentSnackBar();

    if (!isAdmin) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(localeProvider.getString('admin_access_denied')),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminPanelScreen()),
    );
  }


  void _showAbout(BuildContext ctx, LocaleProvider localeProvider) {
    showAboutDialog(
      context: ctx,
      applicationName: 'MusicApp',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.music_note, color: Colors.black, size: 30),
      ),
      children: [
        Text(
          localeProvider.getString('app_description'),
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  void _showLogoutDialog(
    BuildContext context,
    AuthProvider authProvider,
    LocaleProvider localeProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: Text(
          localeProvider.getString('logout_title'),
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          localeProvider.getString('logout_message'),
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              localeProvider.getString('cancel'),
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await authProvider.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: Text(
              localeProvider.getString('logout'),
              style: const TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );
  }
}
