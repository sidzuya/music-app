import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/song_model.dart';
import '../../providers/live_room_provider.dart';
import '../../providers/music_provider.dart';

class LiveRoomScreen extends StatefulWidget {
  const LiveRoomScreen({super.key});

  @override
  State<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends State<LiveRoomScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScroll = ScrollController();
  bool _showChat = false;
  late AnimationController _chatAnimCtrl;
  late Animation<Offset> _chatSlide;

  StreamSubscription? _notifSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chatAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _chatSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _chatAnimCtrl, curve: Curves.easeOut));

    // Listen for room closed notifications
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<LiveRoomProvider>(context, listen: false);
      _notifSub = provider.notificationStream.listen((msg) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      final provider = Provider.of<LiveRoomProvider>(context, listen: false);
      if (provider.isHost) {
        provider.leaveRoom();
      }
    }
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _chatController.dispose();
    _chatScroll.dispose();
    _chatAnimCtrl.dispose();
    super.dispose();
  }

  void _toggleChat() {
    setState(() => _showChat = !_showChat);
    if (_showChat) {
      _chatAnimCtrl.forward();
    } else {
      _chatAnimCtrl.reverse();
    }
  }

  Future<void> _leaveRoom() async {
    final provider = Provider.of<LiveRoomProvider>(context, listen: false);
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Покинуть комнату?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          provider.isHost
              ? 'Вы хост. Комната закроется для всех.'
              : 'Синхронизация прекратится.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Покинуть',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;

    if (shouldLeave && context.mounted) {
      await provider.leaveRoom();
      Navigator.pop(context);
    }
  }

  // Just minimize — room stays active in background
  void _minimize() {
    Navigator.pop(context);
  }

  void _sendMessage() {
    if (_chatController.text.trim().isEmpty) return;
    Provider.of<LiveRoomProvider>(context, listen: false)
        .sendMessage(_chatController.text.trim());
    _chatController.clear();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(
          _chatScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: Consumer2<LiveRoomProvider, MusicProvider>(
          builder: (context, liveRoom, music, _) {
            final song = music.currentSong;
            final isHost = liveRoom.isHost;
            final bgColor = const Color(0xFF0A0A1A);

            return Stack(
              children: [
                // Blurred album art background
                if (song?.albumArt != null)
                  Positioned.fill(
                    child: Image.network(song!.albumArt!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: bgColor)),
                  ),
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                    child: Container(
                        color: const Color(0xFF0A0A1A).withValues(alpha: 0.75)),
                  ),
                ),

                // Main content
                SafeArea(
                  child: Column(
                    children: [
                      _buildTopBar(context, liveRoom),
                      Expanded(
                        child: _buildMainContent(song, isHost, liveRoom, music),
                      ),
                      _buildBottomBar(liveRoom, music, isHost),
                    ],
                  ),
                ),

                // Chat overlay
                if (_showChat)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _toggleChat,
                      child: Container(color: Colors.black54),
                    ),
                  ),
                if (_showChat)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: MediaQuery.of(context).size.height * 0.55,
                    child: SlideTransition(
                      position: _chatSlide,
                      child: _buildChatPanel(liveRoom),
                    ),
                  ),
              ],
            );
          },
        ),
      );
  }

  Widget _buildTopBar(BuildContext context, LiveRoomProvider liveRoom) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down,
                color: Colors.white, size: 32),
            onPressed: _minimize,
          ),
          Expanded(
            child: Column(
              children: [
                Text('LIVE ROOM',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2)),
                Text(
                  liveRoom.currentRoom?.name ?? '',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          // Live indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.circle, color: Colors.white, size: 8),
                SizedBox(width: 4),
                Text('LIVE',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white70),
            onPressed: _leaveRoom,
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(SongModel? song, bool isHost,
      LiveRoomProvider liveRoom, MusicProvider music) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 1),

          // Album art
          Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                    blurRadius: 40,
                    spreadRadius: 10),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: song?.albumArt != null
                  ? Image.network(song!.albumArt!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _defaultAlbumArt())
                  : _defaultAlbumArt(),
            ),
          ),
          const SizedBox(height: 32),

          // Song info
          if (song != null) ...[
            Text(
              song.title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              song.artist,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            Text(
              isHost ? 'Включите музыку в плеере' : 'Ожидание хоста...',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 16),
              textAlign: TextAlign.center,
            ),
            if (!isHost) ...[
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => liveRoom.requestSync(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sync, color: Theme.of(context).colorScheme.primary, size: 18),
                      SizedBox(width: 8),
                      Text('Синхронизировать',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ],

          const SizedBox(height: 20),

          // Progress bar (host only — listeners sync automatically)
          if (song != null && isHost) ...[
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: music.progress.clamp(0.0, 1.0),
                onChanged: (v) => music.seekTo(
                    Duration(
                        milliseconds:
                            (v * music.duration.inMilliseconds).toInt())),
                activeColor: Theme.of(context).colorScheme.primary,
                inactiveColor: Colors.white24,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fmt(music.position),
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12)),
                  Text(_fmt(music.duration),
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12)),
                ],
              ),
            ),
          ] else if (song != null) ...[
            // Listener: show readonly progress
            LinearProgressIndicator(
              value: (isHost ? music.progress : liveRoom.listenerProgress).clamp(0.0, 1.0),
              backgroundColor: Colors.white12,
              color: Theme.of(context).colorScheme.primary,
              minHeight: 3,
              borderRadius: BorderRadius.circular(4),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fmt(isHost ? music.position : liveRoom.listenerPosition),
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12)),
                  Text(_fmt(isHost ? music.duration : liveRoom.listenerDuration),
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12)),
                ],
              ),
            ),
          ],

          const Spacer(flex: 1),

          // Host controls
          if (isHost && song != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _controlBtn(
                    Icons.skip_previous_rounded, 40, () => music.skipToPrevious()),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => music.togglePlayPause(),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                            blurRadius: 20)
                      ],
                    ),
                    child: Icon(
                      music.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.black,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                _controlBtn(
                    Icons.skip_next_rounded, 40, () => music.skipToNext()),
              ],
            ),

          if (!isHost && song != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline,
                      color: Colors.white38, size: 16),
                  const SizedBox(width: 6),
                  Text('Управляет хост',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 13)),
                ],
              ),
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildBottomBar(
      LiveRoomProvider liveRoom, MusicProvider music, bool isHost) {
    final users = liveRoom.presenceUsers;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          // Avatars
          Expanded(
            child: SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: users.length,
                itemBuilder: (_, i) {
                  final u = users[i];
                  final name = (u['username'] as String? ?? 'U');
                  final avatar = u['avatar_url'] as String?;
                  return Align(
                    widthFactor: 0.7,
                    child: Tooltip(
                      message: name,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        backgroundImage:
                            avatar != null ? NetworkImage(avatar) : null,
                        child: avatar == null
                            ? Text(name[0].toUpperCase(),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold))
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Chat button
          GestureDetector(
            onTap: _toggleChat,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _showChat
                        ? Theme.of(context).colorScheme.primary
                        : Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chat_bubble_outline,
                      color: Colors.white, size: 20),
                ),
                if (liveRoom.messages.isNotEmpty)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPanel(LiveRoomProvider liveRoom) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Чат',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
          const Divider(color: Colors.white10),
          Expanded(
            child: liveRoom.messages.isEmpty
                ? Center(
                    child: Text('Пока нет сообщений...',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3))))
                : ListView.builder(
                    controller: _chatScroll,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: liveRoom.messages.length,
                    itemBuilder: (_, i) {
                      final msg = liveRoom.messages[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                              backgroundImage: msg.avatarUrl != null
                                  ? NetworkImage(msg.avatarUrl!)
                                  : null,
                              child: msg.avatarUrl == null
                                  ? Text(msg.username[0].toUpperCase(),
                                      style: TextStyle(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold))
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(msg.username,
                                      style: TextStyle(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text(msg.text,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 14)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          // Input
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 24),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Сообщение...',
                      hintStyle:
                          TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.07),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultAlbumArt() {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: Icon(Icons.music_note_rounded,
          color: Theme.of(context).colorScheme.primary, size: 80),
    );
  }

  Widget _controlBtn(IconData icon, double size, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: Colors.white, size: size),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
