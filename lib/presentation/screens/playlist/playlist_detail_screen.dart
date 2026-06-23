import 'dart:io' if (dart.library.html) 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/playlist_model.dart';
import '../../../data/models/song_model.dart';
import '../../providers/music_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/collab_playlist_provider.dart';
import '../../widgets/song_tile.dart';
import '../player/player_screen.dart';
import 'collab_invite_screen.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final PlaylistModel playlist;
  final bool isCollab;
  final String? collabPlaylistId;

  const PlaylistDetailScreen({
    super.key,
    required this.playlist,
    this.isCollab = false,
    this.collabPlaylistId,
  });

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  String? _localCoverPath;
  List<Map<String, dynamic>> _collaborators = [];
  bool _isCollab = false;
  
  bool _isLoadingCollabSongs = false;

  String? get _playlistUuid {
    if (widget.collabPlaylistId != null) return widget.collabPlaylistId;
    if (widget.playlist.id != null) {
      return Provider.of<PlaylistProvider>(context, listen: false).getPlaylistUuid(widget.playlist.id!);
    }
    return null;
  }
  
  @override
  void initState() {
    super.initState();
    _localCoverPath = widget.playlist.coverImage;
    _isCollab = widget.isCollab || (widget.playlist.id != null && context.read<PlaylistProvider>().getPlaylistUuid(widget.playlist.id!) != null);
    if (_isCollab) {
      _loadCollabInfo();
      _loadCollabSongs();
    }
  }

  void _loadCollabSongs() async {
    final uuid = _playlistUuid;
    if (uuid != null) {
      setState(() => _isLoadingCollabSongs = true);
      final provider = context.read<PlaylistProvider>();
      await provider.fetchCollabSongs(uuid);
      if (mounted) setState(() => _isLoadingCollabSongs = false);
    }
  }

  Future<void> _loadCollabInfo() async {
    final uuid = _playlistUuid;
    if (uuid == null) {
      if (mounted) {
        setState(() {
          _isCollab = false;
        });
      }
      return;
    }
    final provider = context.read<CollabPlaylistProvider>();
    final collaborators = await provider.getCollaborators(uuid);
    final isCollab = await provider.isCollaborator(uuid);
    if (mounted) {
      setState(() {
        _collaborators = collaborators;
        _isCollab = isCollab || collaborators.isNotEmpty;
      });
    }
  }
  
  Widget _defaultCoverWidget() {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.queue_music_rounded, size: 64, color: AppTheme.primaryGreen),
    );
  }

  Future<void> _confirmAndDeletePlaylist(PlaylistProvider playlistProvider, LocaleProvider localeProvider) async {
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: Text(
          localeProvider.getString('delete_playlist'),
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          localeProvider.getString('delete_playlist_confirm'),
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              localeProvider.getString('cancel'),
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: Text(localeProvider.getString('delete')),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirm == true) {
      // For collab playlists opened with a UUID, delete via the UUID directly
      if (widget.collabPlaylistId != null) {
        final collabProvider = context.read<CollabPlaylistProvider>();
        await collabProvider.deleteCollabPlaylist(widget.collabPlaylistId!);
      } else {
        await playlistProvider.deletePlaylist(widget.playlist.id!);
      }
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _pickCoverImage(PlaylistProvider playlistProvider) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );
      
      if (pickedFile != null) {
        setState(() {
          _localCoverPath = pickedFile.path;
        });
        
        // Update playlist with new cover
        final updatedPlaylist = widget.playlist.copyWith(
          coverImage: pickedFile.path,
        );
        await playlistProvider.updatePlaylist(updatedPlaylist);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<LocaleProvider, PlaylistProvider>(
      builder: (context, localeProvider, playlistProvider, child) {
        final songs = playlistProvider.getPlaylistSongs(widget.playlist.id!);
        
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    // ── Beautiful Playlist Header ──
                    SliverAppBar(
                      expandedHeight: 340,
                      pinned: true,
                      stretch: true,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      leading: Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      actions: [
                        Container(
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.more_vert, color: Colors.white),
                            onPressed: () => _showOptionsMenu(context, playlistProvider, localeProvider),
                          ),
                        ),
                      ],
                      flexibleSpace: FlexibleSpaceBar(
                        stretchModes: const [StretchMode.zoomBackground],
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Full background gradient
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  stops: const [0.0, 0.6, 1.0],
                                  colors: [
                                    AppTheme.primaryGreen.withOpacity(0.85),
                                    AppTheme.primaryGreen.withOpacity(0.3),
                                    AppTheme.darkBackground,
                                  ],
                                ),
                              ),
                            ),
                            // Content
                            SafeArea(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Cover art with shadow
                                  GestureDetector(
                                    onTap: () => _pickCoverImage(playlistProvider),
                                    child: Container(
                                      width: 160,
                                      height: 160,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.5),
                                            blurRadius: 30,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: _localCoverPath != null && _localCoverPath!.isNotEmpty
                                                ? (kIsWeb
                                                    ? Image.network(
                                                        _localCoverPath!,
                                                        width: 160,
                                                        height: 160,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (_, __, ___) => _defaultCoverWidget(),
                                                      )
                                                    : Image.file(
                                                        File(_localCoverPath!),
                                                        width: 160,
                                                        height: 160,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (_, __, ___) => _defaultCoverWidget(),
                                                      ))
                                                : _defaultCoverWidget(),
                                          ),
                                          // Camera overlay
                                          Positioned(
                                            right: 8,
                                            bottom: 8,
                                            child: Container(
                                              padding: const EdgeInsets.all(7),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryGreen,
                                                shape: BoxShape.circle,
                                                boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 6)],
                                              ),
                                              child: const Icon(Icons.camera_alt, size: 14, color: Colors.black),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  // Playlist name
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24),
                                    child: Text(
                                      widget.playlist.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  // Meta row: song count + collab badge
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${songs.length} ${localeProvider.getString('songs')}',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 13,
                                        ),
                                      ),
                                      if (_isCollab) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryGreen.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.5)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.people_outline, size: 12, color: AppTheme.primaryGreen),
                                              const SizedBox(width: 4),
                                              const Text(
                                                'Совместный',
                                                style: TextStyle(color: AppTheme.primaryGreen, fontSize: 11, fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (widget.playlist.description != null && widget.playlist.description!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 24),
                                      child: Text(
                                        widget.playlist.description!,
                                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Play / Shuffle Controls ──
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Row(
                          children: [
                            // Play button
                            Expanded(
                              child: GestureDetector(
                                onTap: songs.isNotEmpty ? () => _playAll(context, songs) : null,
                                child: Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: songs.isNotEmpty ? AppTheme.primaryGreen : AppTheme.primaryGreen.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 22),
                                      const SizedBox(width: 6),
                                      Text(
                                        localeProvider.getString('play_all'),
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Shuffle button
                            GestureDetector(
                              onTap: songs.isNotEmpty ? () => _shufflePlay(context, songs) : null,
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppTheme.cardBackground,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Icon(
                                  Icons.shuffle_rounded,
                                  color: songs.isNotEmpty ? Colors.white : Colors.white24,
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Songs List
                    _isLoadingCollabSongs
                        ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
                        : songs.isEmpty
                            ? SliverFillRemaining(
                                hasScrollBody: false,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 32),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(24),
                                        decoration: BoxDecoration(
                                          color: AppTheme.surfaceColor.withOpacity(0.5),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.library_music_rounded,
                                          size: 48,
                                          color: AppTheme.textTertiary.withOpacity(0.5),
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Text(
                                        localeProvider.getString('playlist_empty'),
                                        style: const TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        localeProvider.getString('playlist_empty_help'),
                                        style: TextStyle(
                                          color: AppTheme.textSecondary.withOpacity(0.8),
                                          fontSize: 14,
                                          height: 1.4,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 48), // Bottom padding
                                    ],
                                  ),
                                ),
                              )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final song = songs[index];
                                return Dismissible(
                                  key: Key('${widget.playlist.id}_${song.id}'),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    color: AppTheme.errorColor,
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    child: const Icon(
                                      Icons.delete,
                                      color: Colors.white,
                                    ),
                                  ),
                                  onDismissed: (direction) {
                                    playlistProvider.removeSongFromPlaylist(widget.playlist.id!, song);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('${song.title} удалена'),
                                        action: SnackBarAction(
                                          label: 'Отменить',
                                          onPressed: () {
                                            playlistProvider.addSongToPlaylist(widget.playlist.id!, song);
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                  child: SongTile(
                                    song: song,
                                    onTap: () {
                                      Provider.of<MusicProvider>(context, listen: false)
                                          .playPlaylist(songs, index);
                                    },
                                    showIndex: false,
                                  ),
                                );
                              },
                              childCount: songs.length,
                            ),
                          ),
                  ],
                ),
              ),
              // Mini Player
              Consumer<MusicProvider>(
                builder: (context, musicProvider, child) {
                  if (musicProvider.currentSong == null) {
                    return const SizedBox.shrink();
                  }
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const PlayerScreen(),
                        ),
                      );
                    },
                    child: Container(
                      height: 60,
                      color: AppTheme.cardBackground,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          // Album Art
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceColor,
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
                                          color: Theme.of(context).colorScheme.primary,
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
                              musicProvider.isPlaying ? Icons.pause : Icons.play_arrow,
                              color: AppTheme.textPrimary,
                            ),
                            onPressed: () => musicProvider.togglePlayPause(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _playAll(BuildContext context, List<SongModel> songs) {
    if (songs.isNotEmpty) {
      Provider.of<MusicProvider>(context, listen: false).playSong(songs.first);
    }
  }

  void _shufflePlay(BuildContext context, List<SongModel> songs) {
    if (songs.isNotEmpty) {
      final shuffled = List<SongModel>.from(songs)..shuffle();
      Provider.of<MusicProvider>(context, listen: false).playSong(shuffled.first);
    }
  }

  void _showEditPlaylistDialog(BuildContext context, PlaylistProvider playlistProvider, LocaleProvider localeProvider) {
    final nameController = TextEditingController(text: widget.playlist.name);
    final descriptionController = TextEditingController(text: widget.playlist.description ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: Text(
          localeProvider.getString('edit_playlist'),
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
                final updatedPlaylist = widget.playlist.copyWith(
                  name: name,
                  description: descriptionController.text.trim().isEmpty 
                      ? null 
                      : descriptionController.text.trim(),
                );
                await playlistProvider.updatePlaylist(updatedPlaylist);
                if (context.mounted) {
                  Navigator.pop(context);
                  // Pop the detail screen and go back to library
                  Navigator.pop(context);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.black,
            ),
            child: Text(localeProvider.getString('save')),
          ),
        ],
      ),
    );
  }

  void _showOptionsMenu(BuildContext context, PlaylistProvider playlistProvider, LocaleProvider localeProvider) {
    // Owner = playlist is in their local list OR they opened it as a collab playlist
    // but collabPlaylistId is set (they created it)
    final isOwner = playlistProvider.playlists.any((p) => p.id == widget.playlist.id) &&
        (widget.collabPlaylistId == null ||
            playlistProvider.getPlaylistUuid(widget.playlist.id!) == widget.collabPlaylistId);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: AppTheme.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Invite collaborator (only owner can invite)
            if (isOwner)
              ListTile(
                leading: const Icon(Icons.person_add_outlined, color: AppTheme.primaryGreen),
                title: const Text(
                  'Пригласить соавтора',
                  style: TextStyle(color: AppTheme.primaryGreen),
                ),
                onTap: () {
                  Navigator.pop(context);
                  if (widget.playlist.id != null) {
                    final uuid = playlistProvider.getPlaylistUuid(widget.playlist.id!) ?? widget.playlist.id.toString();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CollabInviteScreen(
                          playlistId: uuid,
                          playlistName: widget.playlist.name,
                        ),
                      ),
                    ).then((_) => _loadCollabInfo());
                  }
                },
              ),
            // Leave playlist (only collaborators, not owners)
            if (!isOwner && _isCollab)
              ListTile(
                leading: const Icon(Icons.exit_to_app, color: AppTheme.errorColor),
                title: const Text(
                  'Покинуть плейлист',
                  style: TextStyle(color: AppTheme.errorColor),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final uuid = _playlistUuid ?? widget.playlist.id.toString();
                  await context.read<CollabPlaylistProvider>().leavePlaylist(uuid);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ListTile(
              leading: const Icon(Icons.edit, color: AppTheme.textPrimary),
              title: Text(
                localeProvider.getString('edit_playlist'),
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                _showEditPlaylistDialog(context, playlistProvider, localeProvider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
              title: Text(
                localeProvider.getString('delete_playlist'),
                style: const TextStyle(color: AppTheme.errorColor),
              ),
              onTap: () {
                // Close the bottom sheet first, then show dialog
                Navigator.pop(context);
                // Delay slightly so the bottom sheet is fully closed before showing dialog
                Future.delayed(const Duration(milliseconds: 200), () {
                  if (!mounted) return;
                  _confirmAndDeletePlaylist(playlistProvider, localeProvider);
                });
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
