import 'package:flutter/material.dart';

import '../../../data/services/admin/admin_storage_service.dart';

class AdminSongsScreen extends StatefulWidget {
  const AdminSongsScreen({super.key});

  @override
  State<AdminSongsScreen> createState() => _AdminSongsScreenState();
}

class _AdminSongsScreenState extends State<AdminSongsScreen> {
  List<AdminSongFile> _allSongs = [];
  List<AdminSongFile> _filteredSongs = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    setState(() => _loading = true);
    final songs = await AdminStorageService.listAllSongs();
    if (!mounted) return;
    setState(() {
      _allSongs = songs;
      _applyFilters();
      _loading = false;
    });
  }

  void _applyFilters() {
    _filteredSongs = _allSongs.where((song) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return song.artist.toLowerCase().contains(query) ||
          song.title.toLowerCase().contains(query) ||
          song.name.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _deleteSong(AdminSongFile song) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить песню?'),
        content: Text('${song.artist} - ${song.title}\nBucket: ${song.bucket}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok = await AdminStorageService.deleteSong(song.bucket, song.name);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Удалено' : 'Ошибка удаления'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );

    if (ok) _loadSongs();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Все песни',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Обновить',
                    onPressed: _loadSongs,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Поиск по названию или исполнителю...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                    _applyFilters();
                  });
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_filteredSongs.length} треков',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filteredSongs.isEmpty
              ? const Center(child: Text('Ничего не найдено'))
              : RefreshIndicator(
                  onRefresh: _loadSongs,
                  child: ListView.builder(
                    itemCount: _filteredSongs.length,
                    itemBuilder: (context, index) {
                      final song = _filteredSongs[index];
                      return _SongTile(
                        song: song,
                        onDelete: () => _deleteSong(song),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _SongTile extends StatelessWidget {
  final AdminSongFile song;
  final VoidCallback onDelete;

  const _SongTile({
    required this.song,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blue.withAlpha(40),
        child: const Icon(
          Icons.music_note,
          color: Colors.blue,
        ),
      ),
      title: Text(song.title, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        song.artist,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Удалить',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: Colors.red),
          ),
        ],
      ),
    );
  }
}
