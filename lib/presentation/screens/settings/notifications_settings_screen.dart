import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/locale_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() => _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState extends State<NotificationsSettingsScreen> {
  bool _pushNotifications = true;
  bool _playlistUpdates = true;
  bool _friendActivity = false;
  bool _loading = true;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final email = auth.currentUser?.email ?? 'anonymous';
    setState(() {
      _userEmail = email;
      _pushNotifications = prefs.getBool('notif_push_enabled_$email') ?? true;
      _playlistUpdates = prefs.getBool('notif_playlists_enabled_$email') ?? true;
      _friendActivity = prefs.getBool('notif_social_enabled_$email') ?? false;
      _loading = false;
    });
  }

  Future<void> _updateSetting(String key, bool value) async {
    final email = _userEmail ?? 'anonymous';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_${key}_enabled_$email', value);
    setState(() {
      if (key == 'push') _pushNotifications = value;
      if (key == 'playlists') _playlistUpdates = value;
      if (key == 'social') _friendActivity = value;
    });
    // Trigger notification service reload to apply filter changes immediately
    try {
      if (!mounted) return;
      Provider.of<NotificationProvider>(context, listen: false).service.initialize();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
        return Scaffold(
          backgroundColor: AppTheme.darkBackground,
          appBar: AppBar(
            title: Text(localeProvider.getString('notifications')),
            backgroundColor: AppTheme.darkBackground,
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // General Settings
                    _buildSectionHeader(localeProvider.getString('general_settings')),
                    const SizedBox(height: 16),
                    _buildSwitchTile(
                      localeProvider.getString('push_notifications'),
                      localeProvider.getString('push_notifications_desc'),
                      _pushNotifications,
                      (value) => _updateSetting('push', value),
                    ),
                    const SizedBox(height: 32),

                    // Music Notifications
                    _buildSectionHeader(localeProvider.getString('music_notifications')),
                    const SizedBox(height: 16),
                    _buildSwitchTile(
                      localeProvider.getString('playlist_updates'),
                      localeProvider.getString('playlist_updates_desc'),
                      _playlistUpdates,
                      (value) => _updateSetting('playlists', value),
                      enabled: _pushNotifications,
                    ),
                    const SizedBox(height: 32),

                    // Social Notifications
                    _buildSectionHeader(localeProvider.getString('social_notifications')),
                    const SizedBox(height: 16),
                    _buildSwitchTile(
                      localeProvider.getString('friend_activity'),
                      localeProvider.getString('friend_activity_desc'),
                      _friendActivity,
                      (value) => _updateSetting('social', value),
                      enabled: _pushNotifications,
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged, {
    bool enabled = true,
  }) {
    return SwitchListTile(
      title: Text(
        title,
        style: TextStyle(
          color: enabled ? AppTheme.textPrimary : AppTheme.textTertiary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: enabled ? AppTheme.textSecondary : AppTheme.textTertiary,
        ),
      ),
      value: enabled ? value : false,
      onChanged: enabled ? onChanged : null,
      activeColor: Theme.of(context).colorScheme.primary,
    );
  }
}
