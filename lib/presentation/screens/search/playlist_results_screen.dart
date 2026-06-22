import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/search_results.dart';
import '../../../data/models/song_model.dart';
import '../../../data/services/supabase_database_service.dart';
import '../../../data/services/follow_service.dart';
import '../../providers/music_provider.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/song_tile.dart';

/// Read-only view of a public playlist surfaced through global search.
class PlaylistResultsScreen extends StatefulWidget {
  final PlaylistSummary playlist;
  final FollowService? followService;
  final SupabaseDatabaseService? databaseService;

  const PlaylistResultsScreen({
    super.key,
    required this.playlist,
    this.followService,
    this.databaseService,
  });

  @override
  State<PlaylistResultsScreen> createState() => _PlaylistResultsScreenState();
}

class _PlaylistResultsScreenState extends State<PlaylistResultsScreen> {
  late final SupabaseDatabaseService _service;
  late final FollowService _followService;
  List<SongModel> _songs = const [];
  bool _loading = true;
  bool _isPlaylistPrivate = false;

  @override
  void initState() {
    super.initState();
    _service = widget.databaseService ?? SupabaseDatabaseService();
    _followService = widget.followService ?? FollowService();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final ownerId = widget.playlist.ownerId;
    bool isPlaylistPrivate = false;

    if (ownerId != null && ownerId != myId) {
      final ownerProfile = await _followService.getProfile(ownerId);
      if (ownerProfile != null && !ownerProfile.playlistsVisible) {
        isPlaylistPrivate = true;
      }
    }

    if (isPlaylistPrivate) {
      if (!mounted) return;
      setState(() {
        _isPlaylistPrivate = true;
        _songs = const [];
        _loading = false;
      });
      return;
    }

    final songs = await _service.getPlaylistSongs(widget.playlist.id);
    if (!mounted) return;
    setState(() {
      _isPlaylistPrivate = false;
      _songs = songs;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cover = widget.playlist.coverUrl;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(widget.playlist.name),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 200,
                  height: 200,
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
                            size: 80,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.playlist.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.playlist.ownerUsername != null) ...[
              const SizedBox(height: 4),
              Text(
                '@${widget.playlist.ownerUsername!}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ],
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_isPlaylistPrivate)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        Provider.of<LocaleProvider>(context, listen: false)
                            .getString('playlists_hidden_by_settings'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_songs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'No tracks in this playlist',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              )
            else
              ..._songs.map(
                (s) => SongTile(
                  song: s,
                  onTap: () {
                    Provider.of<MusicProvider>(context, listen: false)
                        .playPlaylist(_songs, _songs.indexOf(s));
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
