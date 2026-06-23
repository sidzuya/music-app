import 'dart:math';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/song_model.dart';
import '../../../data/services/featured_songs_service.dart';
import '../../../data/services/hybrid_music_service.dart';
import '../../../data/services/songs_catalog_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/follow_provider.dart';
import '../../providers/music_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/recommendation_provider.dart';
import '../../widgets/song_tile.dart';
import '../../widgets/playlist_card.dart';
import '../search/search_screen.dart';
import '../library/library_screen.dart';
import '../player/player_screen.dart';
import '../profile/profile_screen.dart';
import '../ai_playlist/ai_playlist_screen.dart';
import '../recommendations/ai_recommendations_screen.dart';
import '../social/live_rooms_list_screen.dart';
import '../social/live_room_screen.dart';
import '../../providers/live_room_provider.dart';
import '../../providers/friend_activity_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/collab_playlist_provider.dart';
import '../../widgets/application_status_banner.dart';
import '../../../core/utils/date_formatter_utils.dart';
import 'notifications_screen.dart';
import '../settings/account_settings_screen.dart';
import '../player/recently_played_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final HybridMusicService _musicService = HybridMusicService();
  final FeaturedSongsService _featuredService = FeaturedSongsService.instance;
  final GlobalKey<SearchScreenState> _searchScreenKey =
      GlobalKey<SearchScreenState>();
  List<SongModel> _featuredSongs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        try {
          context.read<NotificationProvider>().service.initialize();
        } catch (_) {}
        await _handleTrackUrlParam();
      }
    });
  }

  Future<void> _handleTrackUrlParam() async {
    try {
      final trackId = Uri.base.queryParameters['track'] ?? _parseTrackFromFragment();
      if (trackId != null && trackId.isNotEmpty) {
        debugPrint('HomeScreen: Found track query parameter: $trackId');
        final catalogSong = await SongsCatalogService.fetchById(trackId);
        if (catalogSong != null && mounted) {
          debugPrint('HomeScreen: Automatically playing song "${catalogSong.title}"');
          final musicProvider = Provider.of<MusicProvider>(context, listen: false);
          await musicProvider.playSong(catalogSong.toSongModel());
        } else {
          debugPrint('HomeScreen: Track with ID "$trackId" not found in catalog');
        }
      }
    } catch (e) {
      debugPrint('HomeScreen: Error handling track URL parameter: $e');
    }
  }

  String? _parseTrackFromFragment() {
    try {
      final fragment = Uri.base.fragment;
      if (fragment.isNotEmpty) {
        final cleanFragment = fragment.startsWith('/') ? fragment : '/$fragment';
        final uri = Uri.parse(cleanFragment);
        return uri.queryParameters['track'];
      }
    } catch (_) {}
    return null;
  }

  Future<void> _loadData() async {
    try {
      // Try to fetch real, trending popular songs dynamically from iTunes & Audius APIs
      final popularTracks = await _musicService.getPopularSongs(limit: 30);
      if (popularTracks.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _featuredSongs = popularTracks;
          _isLoading = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('Failed to load popular songs from external APIs: $e. Falling back to storage bucket.');
    }

    // Fallback: load static tracks from Supabase Storage featured bucket
    try {
      final supabaseFeatured = await _featuredService.getAllSongsFromBucket();

      // Convert SupabaseSong to SongModel (newest first — already sorted)
      final featured = supabaseFeatured.map((s) => SongModel(
        id: s.id.hashCode,
        title: s.title,
        artist: s.artist,
        album: 'Featured',
        albumArt: s.coverUrl,
        audioUrl: s.audioUrl,
        duration: Duration.zero,
        genre: '',
        createdAt: s.uploadedAt,
      )).toList();

      if (!mounted) return;
      setState(() {
        _featuredSongs = featured;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading fallback data: $e');
      if (!mounted) return;
      setState(() {
        _featuredSongs = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshHome() async {
    setState(() => _isLoading = true);
    _musicService.clearCache();
    await _loadData();
  }

  @override
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final musicProvider = Provider.of<MusicProvider>(context);
    final mediaQuery = MediaQuery.of(context);
    final bool isDesktop = mediaQuery.size.width >= 900;

    if (isDesktop) {
      return _buildDesktopLayout(context, authProvider, musicProvider);
    } else {
      return _buildMobileLayout(context, authProvider, musicProvider);
    }
  }

  Widget _buildDesktopLayout(BuildContext context, AuthProvider authProvider, MusicProvider musicProvider) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // Application Status Banner (if active)
          const SafeArea(
            bottom: false,
            child: ApplicationStatusBanner(),
          ),
          
          // Main Body Layout
          Expanded(
            child: Row(
              children: [
                // Left Navigation Sidebar
                _buildDesktopSidebar(context, authProvider.currentUser?.username),
                
                // Centered Main Content Area
                Expanded(
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: IndexedStack(
                          index: _currentIndex,
                          children: [
                            _buildHomeTab(authProvider.currentUser?.username),
                            SearchScreen(key: _searchScreenKey),
                            const AiPlaylistScreen(),
                            const LibraryScreen(),
                            const ProfileScreen(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Bottom full-width Playback controls bar
          _buildDesktopPlayerBar(context, musicProvider),
        ],
      ),
    );
  }

  Widget _buildDesktopSidebar(BuildContext context, String? username) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: const Color(0xFF121212), // Deep carbon black
        border: Border(
          right: BorderSide(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Row(
              children: [
                Icon(
                  Icons.music_note,
                  color: Theme.of(context).colorScheme.primary,
                  size: 36,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'MusicApp',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          
          // Navigation links
          _buildSidebarItem(context, Icons.home, 'Главная', 0),
          _buildSidebarItem(context, Icons.search, 'Поиск', 1),
          _buildSidebarItem(context, Icons.auto_awesome, 'AI Плейлист', 2),
          _buildSidebarItem(context, Icons.library_music, 'Библиотека', 3),
          _buildSidebarItem(context, Icons.person, 'Профиль', 4),
          
          const Spacer(),
          
          // User profile brief
          if (username != null)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      username.substring(0, min(1, username.length)).toUpperCase(),
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      username,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(BuildContext context, IconData icon, String label, int index) {
    final isActive = _currentIndex == index;
    return HoverWidget(
      builder: (context, isHovered) {
        return InkWell(
          onTap: () {
            if (index == 0) _refreshHome();
            setState(() {
              _currentIndex = index;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white.withOpacity(0.06)
                  : (isHovered ? Colors.white.withOpacity(0.03) : Colors.transparent),
              border: isActive
                  ? Border(left: BorderSide(color: Theme.of(context).colorScheme.primary, width: 4))
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isActive
                      ? Theme.of(context).colorScheme.primary
                      : (isHovered ? Colors.white : AppTheme.textSecondary),
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isActive
                          ? Colors.white
                          : (isHovered ? Colors.white70 : AppTheme.textSecondary),
                      fontSize: 15,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopPlayerBar(BuildContext context, MusicProvider musicProvider) {
    final currentSong = musicProvider.currentSong;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Time Formatting helper
    String formatDuration(Duration duration) {
      String twoDigits(int n) => n.toString().padLeft(2, '0');
      final minutes = twoDigits(duration.inMinutes.remainder(60));
      final seconds = twoDigits(duration.inSeconds.remainder(60));
      return '$minutes:$seconds';
    }

    double maxVal = musicProvider.duration.inMilliseconds.toDouble();
    double currentVal = musicProvider.position.inMilliseconds.toDouble();
    if (maxVal <= 0) {
      maxVal = 1.0;
      currentVal = 0.0;
    }

    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181818) : AppTheme.lightCardBackground,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: [
          // 1. Song Info (Left, 240px wide)
          SizedBox(
            width: 240,
            child: currentSong != null
                ? Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: currentSong.albumArt != null
                              ? Image.network(
                                  currentSong.albumArt!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.music_note,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                )
                              : Icon(
                                  Icons.music_note,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentSong.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currentSong.artist,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      HoverWidget(
                        builder: (context, isHovered) {
                          return IconButton(
                            icon: Icon(
                              currentSong.isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: currentSong.isFavorite
                                  ? Theme.of(context).colorScheme.primary
                                  : (isHovered ? Colors.white : AppTheme.textSecondary),
                              size: 20,
                            ),
                            onPressed: () => musicProvider.toggleFavorite(),
                          );
                        },
                      ),
                    ],
                  )
                : const SizedBox(),
          ),

          // 2. Playback Controls & Slider (Middle, Expanded)
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Buttons row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    HoverWidget(
                      builder: (context, isHovered) {
                        return IconButton(
                          icon: Icon(
                            Icons.shuffle,
                            color: musicProvider.isShuffleEnabled
                                ? Theme.of(context).colorScheme.primary
                                : (isHovered ? Colors.white : AppTheme.textSecondary),
                            size: 20,
                          ),
                          onPressed: () => musicProvider.toggleShuffle(),
                        );
                      },
                    ),
                    const SizedBox(width: 16),
                    HoverWidget(
                      builder: (context, isHovered) {
                        return IconButton(
                          icon: Icon(
                            Icons.skip_previous,
                            color: isHovered ? Colors.white : AppTheme.textSecondary,
                            size: 24,
                          ),
                          onPressed: () => musicProvider.skipToPrevious(),
                        );
                      },
                    ),
                    const SizedBox(width: 16),
                    HoverWidget(
                      builder: (context, isHovered) {
                        final primaryColor = Theme.of(context).colorScheme.primary;
                        final buttonColor = musicProvider.currentSong != null
                            ? (isHovered ? primaryColor.withValues(alpha: 0.9) : primaryColor)
                            : AppTheme.textSecondary;
                        return GestureDetector(
                          onTap: () => musicProvider.togglePlayPause(),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: isHovered ? 40 : 36,
                            height: isHovered ? 40 : 36,
                            decoration: BoxDecoration(
                              color: buttonColor,
                              shape: BoxShape.circle,
                              boxShadow: isHovered && musicProvider.currentSong != null
                                  ? [
                                      BoxShadow(
                                        color: primaryColor.withOpacity(0.4),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      )
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              musicProvider.isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.black,
                              size: isHovered ? 24 : 22,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 16),
                    HoverWidget(
                      builder: (context, isHovered) {
                        return IconButton(
                          icon: Icon(
                            Icons.skip_next,
                            color: isHovered ? Colors.white : AppTheme.textSecondary,
                            size: 24,
                          ),
                          onPressed: () => musicProvider.skipToNext(),
                        );
                      },
                    ),
                    const SizedBox(width: 16),
                    HoverWidget(
                      builder: (context, isHovered) {
                        final isActive = musicProvider.repeatMode != RepeatMode.off;
                        return IconButton(
                          icon: Icon(
                            musicProvider.repeatMode == RepeatMode.off
                                ? Icons.repeat
                                : (musicProvider.repeatMode == RepeatMode.once
                                    ? Icons.repeat_one
                                    : Icons.repeat),
                            color: isActive
                                ? Theme.of(context).colorScheme.primary
                                : (isHovered ? Colors.white : AppTheme.textSecondary),
                            size: 20,
                          ),
                          onPressed: () => musicProvider.toggleRepeat(),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Slider row
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Row(
                    children: [
                      Text(
                        formatDuration(musicProvider.position),
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                          ),
                          child: Slider(
                            value: currentVal,
                            max: maxVal,
                            activeColor: Theme.of(context).colorScheme.primary,
                            inactiveColor: Colors.white24,
                            onChanged: musicProvider.currentSong == null
                                ? null
                                : (val) {
                                    musicProvider.seekTo(Duration(milliseconds: val.toInt()));
                                  },
                          ),
                        ),
                      ),
                      Text(
                        formatDuration(musicProvider.duration),
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. Volume and Extra settings (Right, 240px wide)
          SizedBox(
            width: 240,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                HoverWidget(
                  builder: (context, isHovered) {
                    return IconButton(
                      icon: Icon(
                        Icons.queue_music,
                        color: isHovered ? Colors.white : AppTheme.textSecondary,
                        size: 22,
                      ),
                      onPressed: () {
                        _showDesktopQueueSheet(context, musicProvider);
                      },
                    );
                  },
                ),
                HoverWidget(
                  builder: (context, isHovered) {
                    return IconButton(
                      icon: Icon(
                        musicProvider.volume == 0.0 ? Icons.volume_off : Icons.volume_up,
                        color: isHovered ? Colors.white : AppTheme.textSecondary,
                        size: 20,
                      ),
                      onPressed: () {
                        if (musicProvider.volume > 0.0) {
                          musicProvider.setVolume(0.0);
                        } else {
                          musicProvider.setVolume(0.7);
                        }
                      },
                    );
                  },
                ),
                SizedBox(
                  width: 100,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                    ),
                    child: Slider(
                      value: musicProvider.volume,
                      max: 1.0,
                      activeColor: Theme.of(context).colorScheme.primary,
                      inactiveColor: Colors.white24,
                      onChanged: (val) {
                        musicProvider.setVolume(val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, AuthProvider authProvider, MusicProvider musicProvider) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          const SafeArea(
            bottom: false,
            child: ApplicationStatusBanner(),
          ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                _buildHomeTab(authProvider.currentUser?.username),
                SearchScreen(key: _searchScreenKey),
                const AiPlaylistScreen(),
                const LibraryScreen(),
                const ProfileScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mini Player
          if (musicProvider.currentSong != null)
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const PlayerScreen()),
                );
              },
              child: Container(
                height: 60,
                color: Theme.of(context).cardColor,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Album Art
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: musicProvider.currentSong!.albumArt != null
                            ? Image.network(
                                musicProvider.currentSong!.albumArt!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.music_note,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    size: 20,
                                  );
                                },
                              )
                            : Icon(
                                Icons.music_note,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Song Info
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            musicProvider.currentSong!.title,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            musicProvider.currentSong!.artist,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Play/Pause Button
                    IconButton(
                      icon: Icon(
                        musicProvider.isPlaying
                            ? Icons.pause
                            : Icons.play_arrow,
                        color: AppTheme.textPrimary,
                      ),
                      onPressed: () => musicProvider.togglePlayPause(),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom Navigation
          Consumer<LocaleProvider>(
            builder: (context, localeProvider, child) {
              return BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: (index) {
                  if (index == 1 && _currentIndex == 1) {
                    _searchScreenKey.currentState?.resetToBrowse();
                    return;
                  }
                  if (index == 0 && _currentIndex == 0) {
                    _refreshHome();
                    return;
                  }
                  if (index == 0) {
                    _refreshHome();
                  }
                  if (index == 4) {
                    context.read<FollowProvider>().refresh();
                  }
                  setState(() {
                    _currentIndex = index;
                  });
                },
                type: BottomNavigationBarType.fixed,
                backgroundColor: AppTheme.cardBackground,
                selectedItemColor: Theme.of(context).colorScheme.primary,
                unselectedItemColor: AppTheme.textSecondary,
                items: [
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.home),
                    label: localeProvider.getString('home'),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.search),
                    label: localeProvider.getString('search'),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.auto_awesome),
                    label: localeProvider.getString('ai_playlist'),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.library_music),
                    label: localeProvider.getString('library'),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.person),
                    label: localeProvider.getString('profile'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab(String? username) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        // App Bar
        Consumer<LocaleProvider>(
          builder: (context, localeProvider, child) {
            return SliverAppBar(
              floating: false,
              pinned: true,
              backgroundColor: AppTheme.darkBackground,
              elevation: 0,
              toolbarHeight: 48,
              actions: [
                Consumer2<NotificationProvider, CollabPlaylistProvider>(
                  builder: (context, notifProvider, collabProvider, child) {
                    final existingCollabPlaylistIds = notifProvider.notifications
                        .where((n) => n.type == 'collab_invite')
                        .map((n) => n.data?['playlist_id'] as String?)
                        .where((id) => id != null)
                        .toSet();

                    final extraInvites = collabProvider.pendingInvites
                        .where((invite) => !existingCollabPlaylistIds.contains(invite.playlistId))
                        .length;

                    final totalUnread = notifProvider.unreadCount + extraInvites;

                    return Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_outlined),
                          color: AppTheme.textPrimary,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                            );
                          },
                        ),
                        if (totalUnread > 0)
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
                                totalUnread > 99 ? '99+' : '$totalUnread',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  color: AppTheme.textPrimary,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AccountSettingsScreen(),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),

        // Content
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Access
                _buildQuickAccess(),
                const SizedBox(height: 24),
                _buildLiveRoomsBanner(context),
                const SizedBox(height: 24),
                _buildFriendsActivityBanner(context),
                const SizedBox(height: 32),
                _buildAiMixesSection(username),
                       // Recently Played - shows only songs that were actually played
                Consumer2<LocaleProvider, MusicProvider>(
                  builder: (context, localeProvider, musicProvider, child) {
                    final recentlyPlayed = musicProvider.recentlyPlayed;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          localeProvider.getString('recently_played'),
                        ),
                        const SizedBox(height: 16),

                        if (recentlyPlayed.isEmpty)
                          Container(
                            height: 100,
                            alignment: Alignment.center,
                            child: Text(
                              localeProvider.getString('nothing_listened'),
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          )
                        else
                          SizedBox(
                            height: 200,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: recentlyPlayed.length,
                              itemBuilder: (context, index) {
                                final song = recentlyPlayed[index];
                                return Padding(
                                  padding: const EdgeInsets.only(right: 16),
                                  child: PlaylistCard(
                                    title: song.title,
                                    subtitle: song.artist,
                                    imageUrl: song.albumArt,
                                    onTap: () {
                                      musicProvider.playSong(song);
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 32),

                // Popular Songs
                if (_featuredSongs.isNotEmpty) ...[
                  Consumer<LocaleProvider>(
                    builder: (context, localeProvider, child) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader(
                            localeProvider.getString('popular_right_now'),
                          ),
                          const SizedBox(height: 16),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _featuredSongs.length,
                            itemBuilder: (context, index) {
                              final song = _featuredSongs[index];
                              return SongTile(
                                song: song,
                                onTap: () {
                                  Provider.of<MusicProvider>(
                                    context,
                                    listen: false,
                                  ).playPlaylist(_featuredSongs, index);
                                },
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAccess() {
    final bool isDesktop = MediaQuery.of(context).size.width >= 900;
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
        final cards = [
          _buildQuickAccessCard(
            localeProvider.getString('liked_songs'),
            Icons.favorite,
            Theme.of(context).colorScheme.primary,
            () => setState(() => _currentIndex = 3),
          ),
          _buildQuickAccessCard(
            localeProvider.getString('ai_playlist'),
            Icons.auto_awesome,
            Colors.purpleAccent,
            () => setState(() => _currentIndex = 2),
          ),
          _buildQuickAccessCard(
            localeProvider.getString('recently_played'),
            Icons.history,
            Theme.of(context).colorScheme.primary,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RecentlyPlayedScreen(),
                ),
              );
            },
          ),
          _buildQuickAccessCard(
            localeProvider.getString('made_for_you'),
            Icons.auto_awesome,
            Colors.orange,
            () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => AiRecommendationsScreen(),
                ),
              );
            },
          ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(localeProvider.getString('quick_access')),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isDesktop ? 4 : 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: isDesktop ? 3.0 : 2.5,
              ),
              itemCount: cards.length,
              itemBuilder: (context, index) => cards[index],
            ),
          ],
        );
      },
    );
  }

  Widget _buildLiveRoomsBanner(BuildContext context) {
    return Consumer<LiveRoomProvider>(
      builder: (context, liveRoom, _) {
        final isActive = liveRoom.currentRoom != null;
        
        return HoverWidget(
          builder: (context, isHovered) {
            return GestureDetector(
              onTap: () {
                if (isActive) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const LiveRoomScreen()),
                  );
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const LiveRoomsListScreen()),
                  );
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isActive 
                        ? [Colors.redAccent, Theme.of(context).colorScheme.primary] 
                        : [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.primary.withValues(alpha: 0.6)
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    if (isActive)
                      BoxShadow(
                        color: Colors.redAccent.withValues(alpha: 0.3),
                        blurRadius: isHovered ? 14 : 10,
                        spreadRadius: isHovered ? 3 : 2,
                      )
                    else if (isHovered)
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -20,
                      bottom: -20,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 200),
                        scale: isHovered ? 1.1 : 1.0,
                        child: Icon(
                          isActive ? Icons.speaker_group : Icons.headset_mic, 
                          size: 100, 
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(isActive ? Icons.multitrack_audio : Icons.stream, color: Colors.white, size: 32),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(isActive ? 'Активная комната' : 'Live-Комнаты', 
                                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                Text(isActive ? liveRoom.currentRoom!.name : 'Слушайте музыку вместе с друзьями', 
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          if (isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                              child: const Text('ВЕРНУТЬСЯ', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            )
                          else
                            AnimatedSlide(
                              duration: const Duration(milliseconds: 150),
                              offset: isHovered ? const Offset(0.15, 0) : Offset.zero,
                              child: const Icon(Icons.chevron_right, color: Colors.white),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFriendsActivityBanner(BuildContext context) {
    return Consumer<FriendActivityProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.activities.isEmpty) {
          return const SizedBox.shrink(); // Ignore if loading initially
        }
        
        if (provider.activities.isEmpty && !provider.isLoading) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Что слушают друзья'),
            const SizedBox(height: 16),
            SizedBox(
              height: 70,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: provider.activities.length,
                itemBuilder: (context, index) {
                  final activity = provider.activities[index];
                  final isRecentlyActive = DateTime.now().difference(activity.updatedAt).inMinutes < 3;
                  final isOnline = activity.isPlaying || (activity.isOnline && isRecentlyActive);
                  
                  String statusText;
                  if (activity.isPlaying) {
                    statusText = activity.songTitle ?? 'Слушает музыку';
                  } else if (isOnline) {
                    statusText = 'В сети';
                  } else {
                    statusText = 'Был(а): ${DateFormatterUtils.getTimeAgo(activity.updatedAt)}';
                  }
                  
                  return GestureDetector(
                    onTap: () {
                      if (activity.isPlaying && activity.songTitle != null && activity.songUrl != null) {
                        final song = SongModel(
                          id: activity.songUrl.hashCode,
                          title: activity.songTitle!,
                          artist: activity.songArtist ?? 'Unknown Artist',
                          album: 'Friend Activity',
                          audioUrl: activity.songUrl,
                          albumArt: activity.songAlbumArt,
                          duration: Duration.zero,
                          genre: '',
                          createdAt: DateTime.now(),
                        );
                        Provider.of<MusicProvider>(context, listen: false).playSong(song);
                      }
                    },
                    child: Opacity(
                      opacity: isOnline ? 1.0 : 0.6,
                      child: Container(
                        width: 200,
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                              backgroundImage: activity.user.profileImage != null 
                                  ? NetworkImage(activity.user.profileImage!) 
                                  : null,
                              child: activity.user.profileImage == null 
                                  ? Icon(Icons.person, color: Theme.of(context).colorScheme.primary) 
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    activity.user.username,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    statusText,
                                    style: TextStyle(
                                      color: isOnline ? AppTheme.textSecondary : Colors.grey,
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAiMixesSection(String? username) {
    return Consumer2<LocaleProvider, RecommendationProvider>(
      builder: (context, localeProvider, recommendationProvider, child) {
        final mixes = recommendationProvider.dailyMixes;
        final title = username == null || username.isEmpty
            ? localeProvider.getString('just_for_you')
            : '${localeProvider.getString('just_for_you')},\n$username';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => AiRecommendationsScreen(),
                      ),
                    );
                  },
                  child: Text(localeProvider.getString('show_all')),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (recommendationProvider.isLoading && mixes.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (mixes.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localeProvider.getString('start_listening_for_ai'),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      localeProvider.getString('ai_empty_state'),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                height: 240,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: mixes.length,
                  itemBuilder: (context, index) {
                    final mix = mixes[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: PlaylistCard(
                        title: mix.title,
                        subtitle: mix.subtitle,
                        imageUrl: mix.coverImage,
                        width: 220,
                        height: 240,
                        onTap: () {
                          Provider.of<MusicProvider>(
                            context,
                            listen: false,
                          ).playPlaylist(mix.songs, 0);
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildQuickAccessCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return HoverWidget(
      builder: (context, isHovered) {
        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isHovered
                  ? AppTheme.cardBackground.withOpacity(0.8)
                  : AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(8),
              boxShadow: isHovered
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      )
                    ]
                  : null,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: isHovered ? 64 : 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      bottomLeft: Radius.circular(8),
                    ),
                  ),
                  child: Icon(icon, color: Colors.white, size: isHovered ? 26 : 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
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
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  void _showDesktopQueueSheet(BuildContext context, MusicProvider musicProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return _DesktopQueueContent(
              musicProvider: musicProvider,
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'good_morning';
    if (hour < 17) return 'good_afternoon';
    return 'good_evening';
  }
}

/// Desktop queue bottom sheet with drag-and-drop
class _DesktopQueueContent extends StatelessWidget {
  final MusicProvider musicProvider;
  final ScrollController scrollController;

  const _DesktopQueueContent({
    required this.musicProvider,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: musicProvider,
      builder: (context, _) {
        final playlist = musicProvider.playlist;
        final currentSong = musicProvider.currentSong;
        final currentIndex = musicProvider.currentIndex;

        final upcomingSongs = playlist.isNotEmpty && currentIndex < playlist.length
            ? playlist.sublist(currentIndex + 1)
            : <SongModel>[];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textTertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Очередь воспроизведения',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              // Now Playing
              const Text(
                'Сейчас играет',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (currentSong != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: currentSong.albumArt != null
                            ? Image.network(
                                currentSong.albumArt!,
                                width: 48, height: 48, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _cover(48),
                              )
                            : _cover(48),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(currentSong.title,
                                style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(currentSong.artist,
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      const Icon(Icons.volume_up, color: AppTheme.primaryGreen, size: 20),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              // Upcoming header
              Row(
                children: [
                  const Text('Далее',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (upcomingSongs.isNotEmpty)
                    Text('${upcomingSongs.length} треков',
                        style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              if (upcomingSongs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('Очередь пуста',
                        style: TextStyle(color: AppTheme.textTertiary, fontStyle: FontStyle.italic)),
                  ),
                )
              else
                Expanded(
                  child: ReorderableListView.builder(
                    scrollController: scrollController,
                    itemCount: upcomingSongs.length,
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, child) {
                          final elevation = Tween<double>(begin: 0, end: 8).animate(animation).value;
                          return Material(
                            elevation: elevation,
                            color: AppTheme.cardBackground,
                            borderRadius: BorderRadius.circular(8),
                            child: child,
                          );
                        },
                        child: child,
                      );
                    },
                    onReorder: (oldIndex, newIndex) {
                      musicProvider.reorderQueue(oldIndex, newIndex);
                    },
                    itemBuilder: (context, index) {
                      final song = upcomingSongs[index];
                      final originalIndex = currentIndex + 1 + index;
                      return Dismissible(
                        key: ValueKey('dq_${originalIndex}_${song.title}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.delete_outline, color: Colors.red),
                        ),
                        onDismissed: (_) => musicProvider.removeFromQueue(index),
                        child: Material(
                          key: ValueKey('dq_${originalIndex}_${song.title}'),
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              Navigator.pop(context);
                              musicProvider.playPlaylist(playlist, originalIndex);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: const Padding(
                                      padding: EdgeInsets.only(right: 8),
                                      child: Icon(Icons.drag_handle, color: AppTheme.textTertiary, size: 20),
                                    ),
                                  ),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: song.albumArt != null
                                        ? Image.network(song.albumArt!, width: 44, height: 44, fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => _cover(44))
                                        : _cover(44),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(song.title,
                                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                                            maxLines: 1, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 2),
                                        Text(song.artist,
                                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                            maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _cover(double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(4)),
      child: Icon(Icons.music_note, color: AppTheme.textTertiary, size: size * 0.5),
    );
  }
}

class HoverWidget extends StatefulWidget {
  final Widget Function(BuildContext context, bool isHovered) builder;
  final MouseCursor cursor;
  
  const HoverWidget({
    super.key,
    required this.builder,
    this.cursor = SystemMouseCursors.click,
  });

  @override
  State<HoverWidget> createState() => _HoverWidgetState();
}

class _HoverWidgetState extends State<HoverWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    bool animationsEnabled = true;
    try {
      animationsEnabled = Provider.of<ThemeProvider>(context).animationsEnabled;
    } catch (_) {}
    final activeHover = animationsEnabled ? _isHovered : false;
    return MouseRegion(
      cursor: widget.cursor,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: widget.builder(context, activeHover),
    );
  }
}
