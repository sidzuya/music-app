import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/catalog_song_model.dart';
import '../../../data/services/songs_catalog_service.dart';
import 'artist_upload_screen.dart';
import 'artist_analytics_screen.dart';

/// Artist's "studio" — list of own uploaded songs with statuses,
/// plus a button to upload a new track.
class ArtistStudioScreen extends StatefulWidget {
  const ArtistStudioScreen({super.key});

  @override
  State<ArtistStudioScreen> createState() => _ArtistStudioScreenState();
}

class _ArtistStudioScreenState extends State<ArtistStudioScreen> {
  late Future<List<CatalogSong>> _songsFuture;

  @override
  void initState() {
    super.initState();
    _songsFuture = SongsCatalogService.mine();
  }

  Future<void> _refresh() async {
    setState(() {
      _songsFuture = SongsCatalogService.mine();
    });
    await _songsFuture;
  }

  Future<void> _openUpload() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ArtistUploadScreen()),
    );
    if (result == true) await _refresh();
  }

  Future<void> _delete(CatalogSong song) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить трек?'),
        content: Text('${song.title} — ${song.artist}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Удалить')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SongsCatalogService.delete(song.id);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Не удалось удалить: $e'),
            backgroundColor: AppTheme.errorColor),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Студия исполнителя'),
        actions: [
          IconButton(
            tooltip: 'Аналитика',
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () {
              final userId = Supabase.instance.client.auth.currentUser?.id;
              if (userId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ошибка: не авторизован')),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ArtistAnalyticsScreen(
                    artistId: userId,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openUpload,
        icon: const Icon(Icons.add),
        label: const Text('Новый трек'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<CatalogSong>>(
          future: _songsFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Ошибка: ${snap.error}'),
                ),
              ]);
            }
            final songs = snap.data ?? const [];
            if (songs.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 80),
                  Icon(Icons.library_music_outlined, size: 56),
                  SizedBox(height: 16),
                  Center(child: Text('У вас пока нет треков')),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: songs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _SongTile(
                song: songs[i],
                onDelete: () => _delete(songs[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  final CatalogSong song;
  final VoidCallback onDelete;
  const _SongTile({required this.song, required this.onDelete});

  Color _statusColor() {
    switch (song.status) {
      case SongStatus.approved:
        return Colors.green;
      case SongStatus.pending:
        return Colors.orange;
      case SongStatus.rejected:
        return AppTheme.errorColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canDelete = song.status != SongStatus.approved;
    return Card(
      child: ListTile(
        leading: song.coverUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(song.coverUrl!,
                    width: 48, height: 48, fit: BoxFit.cover),
              )
            : Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.music_note),
              ),
        title: Text(song.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(song.artist,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.circle, size: 8, color: _statusColor()),
                const SizedBox(width: 6),
                Text(song.statusLabel,
                    style: TextStyle(color: _statusColor(), fontSize: 12)),
                if (song.isFeatured) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.star, size: 12, color: Colors.amber),
                  const Text(' Featured',
                      style: TextStyle(fontSize: 12, color: Colors.amber)),
                ],
              ],
            ),
            if (song.status == SongStatus.rejected &&
                song.reviewNote?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text('Причина: ${song.reviewNote}',
                  style: const TextStyle(fontSize: 12)),
            ],
          ],
        ),
        trailing: canDelete
            ? IconButton(
                tooltip: 'Удалить',
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
              )
            : null,
      ),
    );
  }
}
