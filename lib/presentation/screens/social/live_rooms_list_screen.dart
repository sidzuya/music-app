import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/live_room_service.dart';
import '../../providers/live_room_provider.dart';
import 'live_room_screen.dart';

class LiveRoomsListScreen extends StatefulWidget {
  const LiveRoomsListScreen({super.key});

  @override
  State<LiveRoomsListScreen> createState() => _LiveRoomsListScreenState();
}

class _LiveRoomsListScreenState extends State<LiveRoomsListScreen> {
  final LiveRoomService _service = LiveRoomService();
  List<LiveRoom> _rooms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() => _isLoading = true);
    try {
      // Clear all active rooms from live_rooms table to clean them up completely
      final allRooms = await _service.client.from('live_rooms').select('id');
      for (final r in (allRooms as List)) {
        await _service.deleteRoom(r['id']);
      }
      
      final rooms = await _service.getActiveRooms();
      if (mounted) {
        setState(() {
          _rooms = rooms;
        });
      }
    } catch (e) {
      debugPrint('Failed to load rooms: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _createRoom() {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: const Text('Создать Live-Комнату', style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Название комнаты',
            hintStyle: const TextStyle(color: AppTheme.textSecondary),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.textTertiary)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              final name = nameController.text.trim();
              if (context.mounted) Navigator.pop(context);
              
              final provider = Provider.of<LiveRoomProvider>(context, listen: false);
              await provider.createAndJoinRoom(name);
              
              if (mounted && provider.currentRoom != null) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveRoomScreen()));
              }
            },
            child: const Text('Создать', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Live-Комнаты'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRooms,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createRoom,
        backgroundColor: Theme.of(context).colorScheme.primary,
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('Создать', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rooms.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadRooms,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80, top: 16),
                    itemCount: _rooms.length,
                    itemBuilder: (context, index) {
                      final room = _rooms[index];
                      return _buildRoomCard(room);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.headset_mic_outlined, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text(
            'Нет активных комнат',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Создайте свою комнату, чтобы\nслушать музыку вместе с друзьями!',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(LiveRoom room) {
    final song = room.currentSong;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final provider = Provider.of<LiveRoomProvider>(context, listen: false);
          await provider.joinRoom(room);
          if (mounted && provider.currentRoom != null) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveRoomScreen()));
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar or Cover
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: song?.albumArt != null
                    ? Image.network(song!.albumArt!, width: 64, height: 64, fit: BoxFit.cover)
                    : Container(
                        width: 64,
                        height: 64,
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                        child: Icon(Icons.music_note, color: Theme.of(context).colorScheme.primary),
                      ),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      song != null ? '${song.title} - ${song.artist}' : 'Ничего не играет',
                      style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 10,
                          backgroundImage: room.hostAvatar != null ? NetworkImage(room.hostAvatar!) : null,
                          backgroundColor: AppTheme.textSecondary,
                          child: room.hostAvatar == null ? const Icon(Icons.person, size: 12, color: Colors.white) : null,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          room.hostName ?? 'User',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
