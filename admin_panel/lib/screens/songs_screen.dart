import 'package:flutter/material.dart';

import '../services/storage_service.dart';

class SongsScreen extends StatefulWidget {
  const SongsScreen({super.key});

  @override
  State<SongsScreen> createState() => _SongsScreenState();
}

class _SongsScreenState extends State<SongsScreen> {
  List<SongFile> _allSongs = [];
  List<SongFile> _filtered = [];
  bool _loading = true;
  String _searchQuery = '';
  String _bucketFilter = 'all'; // 'all', 'songs', 'featured'

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    setState(() => _loading = true);
    final songs = await StorageService.listAllSongs();
    if (!mounted) return;
    setState(() {
      _allSongs = songs;
      _applyFilters();
      _loading = false;
    });
  }

  void _applyFilters() {
    _filtered = _allSongs.where((s) {
      if (_bucketFilter != 'all' && s.bucket != _bucketFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return s.artist.toLowerCase().contains(q) ||
            s.title.toLowerCase().contains(q) ||
            s.name.toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  Future<void> _deleteSong(SongFile song) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить песню?'),
        content: Text('${song.artist} - ${song.title}\nиз bucket: ${song.bucket}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final ok = await StorageService.deleteSong(song.bucket, song.name);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Удалено')),
      );
      _loadSongs();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка удаления')),
      );
    }
  }

  Future<void> _moveSong(SongFile song) async {
    final targetBucket = song.bucket == 'songs' ? 'featured' : 'songs';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Переместить песню?'),
        content: Text(
          '${song.artist} - ${song.title}\n'
          '${song.bucket} → $targetBucket',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Переместить'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final ok = await StorageService.moveSong(song.name, song.bucket, targetBucket);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Перемещено в $targetBucket')),
      );
      _loadSongs();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка перемещения')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Все песни'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadSongs),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Поиск по названию или исполнителю...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      setState(() {
                        _searchQuery = v;
                        _applyFilters();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('Все')),
                    ButtonSegment(value: 'songs', label: Text('Songs')),
                    ButtonSegment(value: 'featured', label: Text('Featured')),
                  ],
                  selected: {_bucketFilter},
                  onSelectionChanged: (v) {
                    setState(() {
                      _bucketFilter = v.first;
                      _applyFilters();
                    });
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${_filtered.length} треков',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const Center(child: Text('Ничего не найдено'))
                    : ListView.builder(
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final song = _filtered[index];
                          return _SongTile(
                            song: song,
                            onDelete: () => _deleteSong(song),
                            onMove: () => _moveSong(song),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  final SongFile song;
  final VoidCallback onDelete;
  final VoidCallback onMove;

  const _SongTile({
    required this.song,
    required this.onDelete,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    final isFeatured = song.bucket == 'featured';
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isFeatured ? Colors.amber.withAlpha(40) : Colors.blue.withAlpha(40),
        child: Icon(
          isFeatured ? Icons.star : Icons.music_note,
          color: isFeatured ? Colors.amber : Colors.blue,
        ),
      ),
      title: Text(song.title, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${song.artist}  •  ${song.bucket}',
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: isFeatured ? 'В songs' : 'В featured',
            child: IconButton(
              icon: Icon(
                isFeatured ? Icons.arrow_back : Icons.star_border,
                color: Colors.orange,
              ),
              onPressed: onMove,
            ),
          ),
          Tooltip(
            message: 'Удалить',
            child: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: onDelete,
            ),
          ),
        ],
      ),
    );
  }
}
