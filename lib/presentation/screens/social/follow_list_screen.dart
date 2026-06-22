import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/social_user_model.dart';
import '../../../data/services/follow_service.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/user_tile.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

enum FollowListTab { followers, following, friends }

class FollowListScreen extends StatefulWidget {
  final String userId;
  final String username;
  final FollowListTab initialTab;

  const FollowListScreen({
    super.key,
    required this.userId,
    required this.username,
    this.initialTab = FollowListTab.followers,
  });

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final FollowService _service = FollowService();

  List<SocialUser>? _followers;
  List<SocialUser>? _following;
  List<SocialUser>? _friends;
  bool _loading = true;
  bool _isPrivate = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.index,
    );
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final isSelf = myId != null && myId == widget.userId;
    
    bool allowed = true;
    if (!isSelf) {
      try {
        final profileRow = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', widget.userId)
            .maybeSingle();
        if (profileRow != null) {
          final socialUser = SocialUser.fromMap(Map<String, dynamic>.from(profileRow as Map));
          allowed = socialUser.followersVisible;
        }
      } catch (e) {
        debugPrint('Error loading profile privacy in FollowListScreen: $e');
      }
    }

    if (!allowed) {
      if (!mounted) return;
      setState(() {
        _followers = [];
        _following = [];
        _friends = [];
        _loading = false;
        _isPrivate = true;
      });
      return;
    }

    final results = await Future.wait([
      _service.getFollowers(widget.userId),
      _service.getFollowing(widget.userId),
      _service.getFriends(widget.userId),
    ]);
    if (!mounted) return;
    setState(() {
      _followers = results[0];
      _following = results[1];
      _friends = results[2];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, _) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            title: Text(widget.username),
            bottom: TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: Theme.of(context).colorScheme.primary,
              tabs: [
                Tab(text: localeProvider.getString('followers')),
                Tab(text: localeProvider.getString('following')),
                Tab(text: localeProvider.getString('friends')),
              ],
            ),
          ),
          body: _isPrivate
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline, size: 64, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 16),
                        const Text(
                          'Этот список скрыт настройками приватности',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildList(_followers, localeProvider),
                    _buildList(_following, localeProvider),
                    _buildList(_friends, localeProvider),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildList(List<SocialUser>? users, LocaleProvider localeProvider) {
    if (_loading || users == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (users.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(32),
          children: [
            const SizedBox(height: 60),
            Icon(
              Icons.people_outline,
              size: 64,
              color: AppTheme.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              localeProvider.getString('no_users_yet'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, index) => UserTile(user: users[index]),
      ),
    );
  }
}
