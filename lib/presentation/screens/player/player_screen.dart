import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/report_model.dart';
import '../../../data/models/song_model.dart';
import '../../providers/music_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/report_dialog.dart';
import '../artist/artist_profile_screen.dart';
import '../album/album_detail_screen.dart';
import '../../widgets/playlist_selector_dialog.dart';

import 'package:share_plus/share_plus.dart';
import '../../widgets/share_dialog.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    // Start rotation animation
    _rotationController.repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Consumer<MusicProvider>(
        builder: (context, musicProvider, child) {
          final song = musicProvider.currentSong;
          
          if (song == null) {
            return Center(
              child: Text(
                'No song playing',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  fontSize: 18,
                ),
              ),
            );
          }

          // Control rotation based on play state and animations setting
          bool animationsEnabled = true;
          try {
            animationsEnabled = Provider.of<ThemeProvider>(context).animationsEnabled;
          } catch (_) {}
          if (musicProvider.isPlaying && animationsEnabled) {
            _rotationController.repeat();
          } else {
            _rotationController.stop();
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Top Bar
                  _buildTopBar(context),
                  const SizedBox(height: 40),

                  // Album Art
                  Expanded(
                    flex: 3,
                    child: _buildAlbumArt(song.albumArt),
                  ),
                  const SizedBox(height: 40),

                  // Song Info
                  _buildSongInfo(song.title, song.artist, song.album),
                  const SizedBox(height: 30),

                  // Progress Bar
                  _buildProgressBar(musicProvider),
                  const SizedBox(height: 30),

                  // Controls
                  _buildControls(musicProvider),
                  const SizedBox(height: 20),

                  // Bottom Actions
                  _buildBottomActions(musicProvider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: AppTheme.textPrimary,
            size: 32,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        const Column(
          children: [
            Text(
              'PLAYING FROM PLAYLIST',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'Liked Songs',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(
            Icons.more_vert,
            color: AppTheme.textPrimary,
          ),
          onPressed: () => _showMoreOptions(context),
        ),
      ],
    );
  }

  Widget _buildAlbumArt(String? albumArt) {
    return Center(
      child: AnimatedBuilder(
        animation: _rotationController,
        builder: (context, child) {
          return Transform.rotate(
            angle: _rotationController.value * 2.0 * 3.14159,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: ClipOval(
                child: albumArt != null
                    ? Image.network(
                        albumArt,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildDefaultAlbumArt();
                        },
                      )
                    : _buildDefaultAlbumArt(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDefaultAlbumArt() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryGreen,
            AppTheme.primaryGreen.withOpacity(0.7),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.music_note,
          color: Colors.white,
          size: 80,
        ),
      ),
    );
  }

  Widget _buildSongInfo(String title, String artist, String album) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          artist,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildProgressBar(MusicProvider musicProvider) {
    return Column(
      children: [
        ProgressBar(
          progress: musicProvider.position,
          total: musicProvider.duration,
          onSeek: (duration) {
            musicProvider.seekTo(duration);
          },
          barHeight: 4,
          baseBarColor: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
          progressBarColor: Theme.of(context).colorScheme.primary,
          thumbColor: Theme.of(context).colorScheme.primary,
          thumbRadius: 6,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDuration(musicProvider.position),
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontSize: 12,
              ),
            ),
            Text(
              _formatDuration(musicProvider.duration),
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildControls(MusicProvider musicProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Shuffle
        IconButton(
          icon: Icon(
            Icons.shuffle,
            color: musicProvider.isShuffleEnabled
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).textTheme.bodyMedium?.color,
            size: 28,
          ),
          onPressed: () => musicProvider.toggleShuffle(),
        ),

        // Previous
        IconButton(
          icon: Icon(
            Icons.skip_previous,
            color: Theme.of(context).colorScheme.onBackground,
            size: 36,
          ),
          onPressed: () => musicProvider.skipToPrevious(),
        ),

        // Play/Pause
        GestureDetector(
          onTapDown: (_) => _scaleController.forward(),
          onTapUp: (_) => _scaleController.reverse(),
          onTapCancel: () => _scaleController.reverse(),
          onTap: () => musicProvider.togglePlayPause(),
          child: ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 0.9).animate(_scaleController),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                musicProvider.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Theme.of(context).colorScheme.onPrimary,
                size: 40,
              ),
            ),
          ),
        ),

        // Next
        IconButton(
          icon: Icon(
            Icons.skip_next,
            color: Theme.of(context).colorScheme.onBackground,
            size: 36,
          ),
          onPressed: () => musicProvider.skipToNext(),
        ),

        // Repeat
        IconButton(
          icon: Icon(
            musicProvider.repeatMode == RepeatMode.once
                ? Icons.repeat_one
                : Icons.repeat,
            color: musicProvider.repeatMode != RepeatMode.off
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).textTheme.bodyMedium?.color,
            size: 28,
          ),
          onPressed: () => musicProvider.toggleRepeat(),
        ),
      ],
    );
  }

  Widget _buildBottomActions(MusicProvider musicProvider) {
    final playlistProvider = Provider.of<PlaylistProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final song = musicProvider.currentSong;
    final isFav = song != null ? playlistProvider.isFavorite(song) : false;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: const Icon(
            Icons.share,
            color: AppTheme.textSecondary,
          ),
          onPressed: () async {
            if (song != null) {
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
            }
          },
        ),
        IconButton(
          icon: Icon(
            isFav ? Icons.favorite : Icons.favorite_border,
            color: isFav ? AppTheme.primaryGreen : AppTheme.textSecondary,
          ),
          onPressed: () async {
            if (song != null) {
              final isFavoriteAfter = await playlistProvider.toggleFavorite(song);
              await musicProvider.toggleFavorite();
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isFavoriteAfter
                          ? localeProvider.getString('added_to_favorites')
                          : localeProvider.getString('removed_from_favorites'),
                    ),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            }
          },
        ),
        IconButton(
          icon: const Icon(
            Icons.queue_music,
            color: AppTheme.textSecondary,
          ),
          onPressed: () => _showQueueBottomSheet(context, musicProvider),
        ),
      ],
    );
  }

  void _showQueueBottomSheet(BuildContext context, MusicProvider musicProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return _QueueSheetContent(
              musicProvider: musicProvider,
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }


  void _showMoreOptions(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final song = context.read<MusicProvider>().currentSong;
    if (song == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_add, color: AppTheme.textPrimary),
              title: Text(localeProvider.getString('add_to_playlist'), style: const TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => PlaylistSelectorDialog(song: song),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person, color: AppTheme.textPrimary),
              title: Text(localeProvider.getString('go_to_artist'), style: const TextStyle(color: AppTheme.textPrimary)),
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
            ListTile(
              leading: const Icon(Icons.album, color: AppTheme.textPrimary),
              title: Text(localeProvider.getString('go_to_album'), style: const TextStyle(color: AppTheme.textPrimary)),
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
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: AppTheme.errorColor),
              title: const Text('Пожаловаться',
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                final id = song.audioUrl ?? '${song.title}|${song.artist}';
                showReportDialog(
                  context,
                  targetType: ReportTargetType.song,
                  targetId: id,
                  targetTitle: '${song.title} — ${song.artist}',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}

/// Queue bottom sheet with drag-and-drop reordering
class _QueueSheetContent extends StatefulWidget {
  final MusicProvider musicProvider;
  final ScrollController scrollController;

  const _QueueSheetContent({
    required this.musicProvider,
    required this.scrollController,
  });

  @override
  State<_QueueSheetContent> createState() => _QueueSheetContentState();
}

class _QueueSheetContentState extends State<_QueueSheetContent> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.musicProvider,
      builder: (context, _) {
        final playlist = widget.musicProvider.playlist;
        final currentSong = widget.musicProvider.currentSong;
        final currentIndex = widget.musicProvider.currentIndex;

        final upcomingSongs = playlist.isNotEmpty && currentIndex < playlist.length
            ? playlist.sublist(currentIndex + 1)
            : <SongModel>[];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
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
                _buildNowPlayingTile(currentSong),
              const SizedBox(height: 20),
              // Upcoming header
              Row(
                children: [
                  const Text(
                    'Далее',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (upcomingSongs.isNotEmpty)
                    Text(
                      '${upcomingSongs.length} треков',
                      style: const TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Upcoming songs with drag-and-drop
              if (upcomingSongs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Очередь пуста',
                      style: TextStyle(color: AppTheme.textTertiary, fontStyle: FontStyle.italic),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ReorderableListView.builder(
                    scrollController: widget.scrollController,
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
                      widget.musicProvider.reorderQueue(oldIndex, newIndex);
                    },
                    itemBuilder: (context, index) {
                      final song = upcomingSongs[index];
                      final originalIndex = currentIndex + 1 + index;
                      return _buildQueueTile(
                        key: ValueKey('queue_${originalIndex}_${song.title}'),
                        song: song,
                        index: index,
                        originalIndex: originalIndex,
                        playlist: playlist,
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

  Widget _buildNowPlayingTile(SongModel song) {
    return Container(
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
            child: song.albumArt != null
                ? Image.network(
                    song.albumArt!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildDefaultCover(48),
                  )
                : _buildDefaultCover(48),
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
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  song.artist,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.volume_up, color: AppTheme.primaryGreen, size: 20),
        ],
      ),
    );
  }

  Widget _buildQueueTile({
    required Key key,
    required SongModel song,
    required int index,
    required int originalIndex,
    required List<SongModel> playlist,
  }) {
    return Dismissible(
      key: key,
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
      onDismissed: (_) {
        widget.musicProvider.removeFromQueue(index);
      },
      child: Material(
        key: key,
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            Navigator.pop(context);
            widget.musicProvider.playPlaylist(playlist, originalIndex);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                // Drag handle
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.drag_handle, color: AppTheme.textTertiary, size: 20),
                  ),
                ),
                // Cover art
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: song.albumArt != null
                      ? Image.network(
                          song.albumArt!,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildDefaultCover(44),
                        )
                      : _buildDefaultCover(44),
                ),
                const SizedBox(width: 12),
                // Song info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song.artist,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
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
      ),
    );
  }

  Widget _buildDefaultCover(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(Icons.music_note, color: AppTheme.textTertiary, size: size * 0.5),
    );
  }
}
