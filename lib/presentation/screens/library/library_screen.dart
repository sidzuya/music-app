import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/music_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/collab_playlist_provider.dart';
import '../../../data/models/playlist_model.dart';
import '../../widgets/song_tile.dart';
import '../playlist/playlist_detail_screen.dart';
import '../recommendations/ai_recommendations_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Consumer<LocaleProvider>(
              builder: (context, localeProvider, child) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Text(
                          Provider.of<AuthProvider>(context)
                                  .currentUser
                                  ?.username
                                  .substring(0, 1)
                                  .toUpperCase() ??
                              'U',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          localeProvider.getString('your_library'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Quick Access
            _buildQuickAccess(),

            // Tabs
            Consumer<LocaleProvider>(
              builder: (context, localeProvider, child) {
                return TabBar(
                  controller: _tabController,
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  labelColor: Theme.of(context).colorScheme.onSurface,
                  unselectedLabelColor: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.color,
                  tabs: [
                    Tab(text: localeProvider.getString('recently_played')),
                    Tab(text: localeProvider.getString('playlists')),
                    Tab(text: localeProvider.getString('liked_songs')),
                  ],
                );
              },
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildRecentlyPlayedTab(),
                  _buildPlaylistsTab(),
                  _buildLikedSongsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccess() {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _buildQuickAccessItem(
                  localeProvider.getString('made_for_you'),
                  Icons.favorite,
                  Theme.of(context).colorScheme.primary,
                  () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AiRecommendationsScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickAccessItem(
                  localeProvider.getString('recently_played'),
                  Icons.history,
                  Colors.purple,
                  () => _tabController.animateTo(0),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickAccessItem(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
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
  }

  Widget _buildRecentlyPlayedTab() {
    return Consumer2<LocaleProvider, MusicProvider>(
      builder: (context, localeProvider, musicProvider, child) {
        final songs = musicProvider.recentlyPlayed;
        if (songs.isEmpty) {
          return _buildEmptyState(
            'Нет недавних треков',
            'Песни которые вы слушаете появятся здесь',
            Icons.history,
            localeProvider,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SongTile(
                song: song,
                onTap: () {
                  musicProvider.playPlaylist(songs, index);
                },
                showIndex: false,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPlaylistsTab() {
    return Consumer3<LocaleProvider, PlaylistProvider, CollabPlaylistProvider>(
      builder: (context, localeProvider, playlistProvider, collabProvider, child) {
        final playlists = playlistProvider.playlists;
        final myCollabPlaylists = collabProvider.myCollabPlaylists;
        final mySharedPlaylistIds = collabProvider.mySharedPlaylistIds;

        final regularPlaylists = playlists.where((p) {
          final uuid = playlistProvider.getPlaylistUuid(p.id!);
          return uuid == null || !mySharedPlaylistIds.contains(uuid);
        }).toList();

        final sharedPlaylists = playlists.where((p) {
          final uuid = playlistProvider.getPlaylistUuid(p.id!);
          return uuid != null && mySharedPlaylistIds.contains(uuid);
        }).map((p) {
          return {
            'isMine': true,
            'localModel': p,
            'id': playlistProvider.getPlaylistUuid(p.id!),
            'name': p.name,
            'description': p.description,
            'cover_url': p.coverImage,
            'username': 'вас', // 'from you'
          };
        }).toList();

        final allCollabs = [
          ...sharedPlaylists,
          ...myCollabPlaylists.map((p) => {
                'isMine': false,
                ...p,
              }),
        ];

        return Column(
          children: [
            // Create Playlist Button
            GestureDetector(
              onTap: () => _showCreatePlaylistDialog(
                context,
                playlistProvider,
                localeProvider,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: AppTheme.textSecondary,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localeProvider.getString('create_playlist'),
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            localeProvider.getString('playlist_help'),
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Playlists List
            Expanded(
              child: (regularPlaylists.isEmpty && allCollabs.isEmpty)
                  ? _buildEmptyState(
                      localeProvider.getString('no_playlists'),
                      localeProvider.getString('create_first_playlist'),
                      Icons.playlist_add,
                      localeProvider,
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        // Collab playlists section
                        if (allCollabs.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 8),
                            child: Row(
                              children: [
                                Icon(Icons.people_outline, size: 16, color: AppTheme.primaryGreen),
                                const SizedBox(width: 6),
                                const Text(
                                  'Совместные',
                                  style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          ...allCollabs.map((p) => _buildCollabPlaylistTile(p, localeProvider)),
                          const Divider(color: AppTheme.surfaceColor, height: 24),
                        ],
                        // My playlists
                        if (regularPlaylists.isNotEmpty) ...[
                          ...regularPlaylists.map((playlist) {
                            final songs = playlistProvider.getPlaylistSongs(playlist.id!);
                            return ListTile(
                              leading: Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: playlist.coverImage != null && playlist.coverImage!.isNotEmpty
                                      ? Image.file(
                                          File(playlist.coverImage!),
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Icon(
                                            Icons.queue_music,
                                            color: Theme.of(context).colorScheme.primary,
                                            size: 30,
                                          ),
                                        )
                                      : Icon(
                                          Icons.queue_music,
                                          color: Theme.of(context).colorScheme.primary,
                                          size: 30,
                                        ),
                                ),
                              ),
                              title: Text(
                                playlist.name,
                                style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text(
                                '${songs.length} ${localeProvider.getString('songs')}',
                                style: const TextStyle(color: AppTheme.textSecondary),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppTheme.textSecondary),
                                onPressed: () => playlistProvider.deletePlaylist(playlist.id!),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => PlaylistDetailScreen(playlist: playlist)),
                                );
                              },
                            );
                          }),
                        ],
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCollabPlaylistTile(Map<String, dynamic> playlist, LocaleProvider localeProvider) {
    final isMine = playlist['isMine'] == true;
    final coverUrl = playlist['cover_url'] as String?;

    return ListTile(
      leading: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            Center(
              child: coverUrl != null && coverUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: isMine
                          ? Image.file(
                              File(coverUrl),
                              fit: BoxFit.cover,
                              width: 60,
                              height: 60,
                            )
                          : Image.network(
                              coverUrl,
                              fit: BoxFit.cover,
                              width: 60,
                              height: 60,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(Icons.queue_music, color: AppTheme.primaryGreen, size: 30),
                            ),
                    )
                  : Icon(Icons.queue_music, color: AppTheme.primaryGreen, size: 30),
            ),
            Positioned(
              right: 4,
              bottom: 4,
              child: Icon(Icons.people, color: AppTheme.primaryGreen, size: 14),
            ),
          ],
        ),
      ),
      title: Text(
        playlist['name'] as String? ?? 'Плейлист',
        style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        'от ${playlist['username'] ?? 'Пользователь'}',
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
      onTap: () {
        final uuid = playlist['id']?.toString() ?? '';
        final localModel = playlist['localModel'] as PlaylistModel?;

        final playlistModel = localModel ?? PlaylistModel(
          id: uuid.hashCode,
          name: playlist['name'] as String? ?? '',
          description: playlist['description'] as String?,
          coverImage: playlist['cover_url'] as String?,
          userId: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlaylistDetailScreen(
              playlist: playlistModel, 
              isCollab: true,
              collabPlaylistId: uuid,
            ),
          ),
        );
      },
    );
  }

  void _showCreatePlaylistDialog(
    BuildContext context,
    PlaylistProvider playlistProvider,
    LocaleProvider localeProvider,
  ) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: Text(
          localeProvider.getString('create_playlist'),
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                labelText: localeProvider.getString('playlist_name'),
                labelStyle: const TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.surfaceColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                labelText: localeProvider.getString('playlist_description'),
                labelStyle: const TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.surfaceColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              localeProvider.getString('cancel'),
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                await playlistProvider.createPlaylist(
                  name,
                  descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim(),
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Плейлист "$name" создан'),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.black,
            ),
            child: Text(localeProvider.getString('create')),
          ),
        ],
      ),
    );
  }

  Widget _buildLikedSongsTab() {
    return Consumer2<LocaleProvider, PlaylistProvider>(
      builder: (context, localeProvider, playlistProvider, child) {
        final favoriteSongs = playlistProvider.favoriteSongs;

        if (favoriteSongs.isEmpty) {
          return _buildEmptyState(
            localeProvider.getString('no_liked_songs'),
            localeProvider.getString('liked_songs_help'),
            Icons.favorite_border,
            localeProvider,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: favoriteSongs.length,
          itemBuilder: (context, index) {
            return SongTile(
              song: favoriteSongs[index],
              onTap: () {
                Provider.of<MusicProvider>(
                  context,
                  listen: false,
                ).playSong(favoriteSongs[index]);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(
    String title,
    String subtitle,
    IconData icon,
    LocaleProvider localeProvider,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppTheme.textTertiary),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: AppTheme.textTertiary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
