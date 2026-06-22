import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/song_model.dart';
import '../../../data/services/hybrid_music_service.dart';
import '../../providers/music_provider.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/song_tile.dart';

class AlbumDetailScreen extends StatefulWidget {
  final String albumName;
  final String artistName;
  final String? coverUrl;

  const AlbumDetailScreen({
    super.key,
    required this.albumName,
    required this.artistName,
    this.coverUrl,
  });

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  final HybridMusicService _musicService = HybridMusicService();
  List<SongModel> _songs = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAlbumSongs();
  }

  Future<void> _loadAlbumSongs() async {
    try {
      final results = await _musicService.searchSongs(
        '${widget.artistName} ${widget.albumName}',
        limit: 30,
      );

      final matching = results.where((s) {
        final isAlbumMatch = s.album.toLowerCase() == widget.albumName.toLowerCase();
        final isArtistMatch = s.artist.toLowerCase().contains(widget.artistName.toLowerCase()) ||
            widget.artistName.toLowerCase().contains(s.artist.toLowerCase());
        return isAlbumMatch && isArtistMatch;
      }).toList();

      // If strict filter yields nothing, try filtering only by album name as a fallback
      final finalSongs = matching.isNotEmpty
          ? matching
          : results.where((s) => s.album.toLowerCase() == widget.albumName.toLowerCase()).toList();

      if (mounted) {
        setState(() {
          _songs = finalSongs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          localeProvider.getString('album') == 'album' ? 'Альбом' : localeProvider.getString('album'),
          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppTheme.errorColor),
                  ),
                )
              : CustomScrollView(
                  slivers: [
                    // Album Header Details
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        child: Column(
                          children: [
                            // Cover Image with Shadow/Gradient look
                            Center(
                              child: Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: widget.coverUrl != null && widget.coverUrl!.isNotEmpty
                                      ? Image.network(
                                          widget.coverUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return _buildDefaultCover();
                                          },
                                        )
                                      : _buildDefaultCover(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Title & Artist
                            Text(
                              widget.albumName,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.artistName,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),

                            // Play Button
                            if (_songs.isNotEmpty)
                              ElevatedButton.icon(
                                onPressed: () {
                                  musicProvider.playPlaylist(_songs, 0);
                                },
                                icon: const Icon(Icons.play_arrow, color: Colors.black),
                                label: Text(
                                  localeProvider.getString('play') == 'play' ? 'Слушать' : localeProvider.getString('play'),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Tracks List
                    if (_songs.isEmpty)
                      const SliverFillRemaining(
                        child: Center(
                          child: Text(
                            'Нет доступных треков',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.only(bottom: 24),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final song = _songs[index];
                              return SongTile(
                                song: song,
                                onTap: () {
                                  musicProvider.playPlaylist(_songs, index);
                                },
                              );
                            },
                            childCount: _songs.length,
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _buildDefaultCover() {
    return Container(
      color: AppTheme.surfaceColor,
      child: Icon(
        Icons.album_rounded,
        color: Theme.of(context).colorScheme.primary,
        size: 80,
      ),
    );
  }
}
