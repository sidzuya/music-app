import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/song_model.dart';
import '../providers/playlist_provider.dart';
import '../providers/collab_playlist_provider.dart';
import '../providers/locale_provider.dart';

class PlaylistSelectorDialog extends StatefulWidget {
  final SongModel song;

  const PlaylistSelectorDialog({
    super.key,
    required this.song,
  });

  @override
  State<PlaylistSelectorDialog> createState() => _PlaylistSelectorDialogState();
}

class _PlaylistSelectorDialogState extends State<PlaylistSelectorDialog> {
  bool _isCreating = false;
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<PlaylistProvider, CollabPlaylistProvider, LocaleProvider>(
      builder: (context, playlistProvider, collabProvider, localeProvider, child) {
        return Dialog(
          backgroundColor: AppTheme.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
              maxWidth: 400,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _isCreating
                              ? localeProvider.getString('create_playlist')
                              : localeProvider.getString('select_playlist'),
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(color: AppTheme.surfaceColor, height: 1),

                // Content
                Expanded(
                  child: _isCreating 
                      ? _buildCreatePlaylist(localeProvider, playlistProvider) 
                      : _buildPlaylistList(playlistProvider, collabProvider, localeProvider),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaylistList(PlaylistProvider playlistProvider, CollabPlaylistProvider collabProvider, LocaleProvider localeProvider) {
    final mySharedPlaylistIds = collabProvider.mySharedPlaylistIds;

    // Regular playlists
    final regularPlaylists = playlistProvider.playlists.where((p) {
      final uuid = playlistProvider.getPlaylistUuid(p.id!);
      return uuid == null || !mySharedPlaylistIds.contains(uuid);
    }).map((p) => {
      'isCollab': false,
      'id': p.id,
      'name': p.name,
      'cover_url': p.coverImage,
      'songCount': playlistProvider.getPlaylistSongs(p.id!).length,
      'playlist': p,
    }).toList();

    // Collab playlists I created and shared
    final sharedPlaylists = playlistProvider.playlists.where((p) {
      final uuid = playlistProvider.getPlaylistUuid(p.id!);
      return uuid != null && mySharedPlaylistIds.contains(uuid);
    }).map((p) => {
      'isCollab': true,
      'id': playlistProvider.getPlaylistUuid(p.id!), // UUID string
      'name': p.name,
      'cover_url': p.coverImage,
      'songCount': 0, // Not loaded easily here
    }).toList();

    // Collab playlists others shared with me
    final collabPlaylists = collabProvider.myCollabPlaylists.map((p) => {
      'isCollab': true,
      'id': p['id'], // UUID string
      'name': p['name'] ?? 'Плейлист',
      'cover_url': p['cover_url'],
      'songCount': 0, 
    }).toList();

    final allPlaylists = [...regularPlaylists, ...sharedPlaylists, ...collabPlaylists];

    return Column(
      children: [
        // Create new playlist button
        ListTile(
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add, color: Colors.black, size: 30),
          ),
          title: Text(
            localeProvider.getString('new_playlist'),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          onTap: () {
            setState(() {
              _isCreating = true;
            });
          },
        ),
        const Divider(color: AppTheme.surfaceColor, height: 1),

        // Existing playlists
        Expanded(
          child: allPlaylists.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      localeProvider.getString('no_playlists_yet'),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: allPlaylists.length,
                  itemBuilder: (context, index) {
                    final item = allPlaylists[index];
                    final isCollab = item['isCollab'] as bool;
                    final coverUrl = item['cover_url'] as String?;
                    
                    return ListTile(
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isCollab ? AppTheme.primaryGreen.withValues(alpha: 0.15) : AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: coverUrl != null && coverUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(coverUrl),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      isCollab ? Icons.people : Icons.queue_music,
                                      color: Theme.of(context).colorScheme.primary,
                                      size: 28,
                                    );
                                  },
                                ),
                              )
                            : Icon(
                                isCollab ? Icons.people : Icons.queue_music,
                                color: Theme.of(context).colorScheme.primary,
                                size: 28,
                              ),
                      ),
                      title: Text(
                        item['name'] as String,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        isCollab 
                            ? 'Совместный плейлист' 
                            : '${item['songCount']} ${localeProvider.getString('songs')}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () {
                        if (isCollab) {
                          _addToCollabPlaylist(collabProvider, item['id'] as String, localeProvider);
                        } else {
                          _addToPlaylist(playlistProvider, item['id'] as int, localeProvider);
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCreatePlaylist(LocaleProvider localeProvider, PlaylistProvider playlistProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameController,
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
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
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
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _isCreating = false;
                    _nameController.clear();
                    _descriptionController.clear();
                  });
                },
                child: Text(
                  localeProvider.getString('cancel'),
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _createAndAddToPlaylist(playlistProvider, localeProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(localeProvider.getString('create')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addToPlaylist(PlaylistProvider playlistProvider, int playlistId, LocaleProvider localeProvider) async {
    final success = await playlistProvider.addSongToPlaylist(playlistId, widget.song);
    
    if (!mounted) return;
    
    Navigator.pop(context);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? localeProvider.getString('added_to_playlist')
              : localeProvider.getString('already_in_playlist'),
        ),
        backgroundColor: success ? Theme.of(context).colorScheme.primary : AppTheme.errorColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _addToCollabPlaylist(CollabPlaylistProvider collabProvider, String playlistId, LocaleProvider localeProvider) async {
    final success = await collabProvider.addSong(playlistId, widget.song);
    
    if (!mounted) return;
    
    Navigator.pop(context);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? localeProvider.getString('added_to_playlist')
              : localeProvider.getString('already_in_playlist'), // Using same message for simplicity
        ),
        backgroundColor: success ? Theme.of(context).colorScheme.primary : AppTheme.errorColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _createAndAddToPlaylist(PlaylistProvider playlistProvider, LocaleProvider localeProvider) async {
    final name = _nameController.text.trim();
    
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localeProvider.getString('playlist_name_required')),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final playlist = await playlistProvider.createPlaylist(
      name,
      _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
    );

    if (playlist != null && mounted) {
      await playlistProvider.addSongToPlaylist(playlist.id!, widget.song);
      
      if (!mounted) return;
      
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localeProvider.getString('added_to_playlist')),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
