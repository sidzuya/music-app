import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/song_model.dart';
import '../providers/locale_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/artist/artist_profile_screen.dart';
import '../screens/album/album_detail_screen.dart';
import 'playlist_selector_dialog.dart';
import 'package:share_plus/share_plus.dart';
import 'share_dialog.dart';

class SongTile extends StatelessWidget {
  final SongModel song;
  final VoidCallback? onTap;
  final VoidCallback? onMoreTap;
  final bool showIndex;
  final int? index;

  const SongTile({
    super.key,
    required this.song,
    this.onTap,
    this.onMoreTap,
    this.showIndex = false,
    this.index,
  });

  @override
  Widget build(BuildContext context) {
    bool showArt = true;
    try {
      showArt = Provider.of<ThemeProvider>(context).showAlbumArt;
    } catch (_) {}

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Leading (Index or Album Art)
            if (showIndex && index != null)
              SizedBox(
                width: 40,
                child: Center(
                  child: Text(
                    '${index! + 1}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
            else if (showArt)
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: song.albumArt != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          song.albumArt!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.music_note,
                              color: Theme.of(context).colorScheme.primary,
                              size: 24,
                            );
                          },
                        ),
                      )
                    : Icon(
                        Icons.music_note,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
              ),
            if ((showIndex && index != null) || showArt)
              const SizedBox(width: 12),
            
            // Song Info (Expanded to prevent overflow)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    song.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            
            // Trailing (Favorite, More)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (song.isFavorite) ...[
                  Icon(
                    Icons.favorite,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                ],
                GestureDetector(
                  onTap: onMoreTap ?? () => _showMoreOptions(context),
                  child: const Icon(
                    Icons.more_vert,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SongOptionsBottomSheet(song: song),
    );
  }
}

class SongOptionsBottomSheet extends StatelessWidget {
  final SongModel song;

  const SongOptionsBottomSheet({
    super.key,
    required this.song,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textTertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),

                // Song Info
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: song.albumArt != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                song.albumArt!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.music_note,
                                    color: Theme.of(context).colorScheme.primary,
                                    size: 24,
                                  );
                                },
                              ),
                            )
                          : Icon(
                              Icons.music_note,
                              color: Theme.of(context).colorScheme.primary,
                              size: 24,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            song.artist,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Options
                Consumer2<LocaleProvider, PlaylistProvider>(
                  builder: (context, localeProvider, playlistProvider, child) {
                    final isFav = playlistProvider.isFavorite(song);
                    
                    return Column(
                      children: [
                        _buildOption(
                          context: context,
                          icon: isFav ? Icons.favorite : Icons.favorite_border,
                          title: isFav 
                              ? localeProvider.getString('remove_from_favorites')
                              : localeProvider.getString('add_to_favorites'),
                          onTap: () {
                            Navigator.pop(context);
                            _toggleFavorite(context, playlistProvider, localeProvider);
                          },
                        ),
                        _buildOption(
                          context: context,
                          icon: Icons.playlist_add,
                          title: localeProvider.getString('add_to_playlist'),
                          onTap: () {
                            Navigator.pop(context);
                            _showPlaylistSelector(context);
                          },
                        ),
                          _buildOption(
                           context: context,
                           icon: Icons.share,
                           title: localeProvider.getString('share'),
                            onTap: () async {
                              Navigator.pop(context);
                              final trackId = song.backendId ?? song.id.toString();
                              String shareUrl;
                              if (kIsWeb) {
                                final uri = Uri.base;
                                final origin = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
                                shareUrl = '$origin/?track=$trackId';
                              } else {
                                shareUrl = '${AppConstants.webAppUrl}/?track=$trackId';
                              }
                              
                              if (kIsWeb) {
                                showShareDialog(context, song, shareUrl);
                              } else {
                                // Always copy to clipboard first
                                Clipboard.setData(ClipboardData(text: shareUrl));
                                
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Ссылка на трек скопирована в буфер обмена'),
                                      backgroundColor: Theme.of(context).colorScheme.primary,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                                
                                try {
                                  final box = context.findRenderObject() as RenderBox?;
                                  final rect = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
                                  await Share.share(
                                    'Послушай трек "${song.title}" исполнителя "${song.artist}" на MusicApp: $shareUrl',
                                    sharePositionOrigin: rect,
                                  );
                                } catch (e) {
                                  debugPrint('Native share failed or not supported: $e');
                                }
                              }
                            },
                         ),
                        _buildOption(
                          context: context,
                          icon: Icons.person,
                          title: localeProvider.getString('go_to_artist'),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ArtistProfileScreen(
                                  artistId: '',
                                  artistName: song.artist,
                                ),
                              ),
                            );
                          },
                        ),
                        _buildOption(
                          context: context,
                          icon: Icons.album,
                          title: localeProvider.getString('go_to_album'),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AlbumDetailScreen(
                                  albumName: song.album,
                                  artistName: song.artist,
                                  coverUrl: song.albumArt,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(
              icon,
              color: AppTheme.textPrimary,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleFavorite(BuildContext context, PlaylistProvider playlistProvider, LocaleProvider localeProvider) async {
    final isFavorite = await playlistProvider.toggleFavorite(song);
    
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isFavorite
              ? localeProvider.getString('added_to_favorites')
              : localeProvider.getString('removed_from_favorites'),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showPlaylistSelector(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => PlaylistSelectorDialog(song: song),
    );
  }
}
