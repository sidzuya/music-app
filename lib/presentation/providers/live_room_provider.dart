import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/song_model.dart';
import '../../data/services/live_room_service.dart';
import 'music_provider.dart';

class LiveRoomProvider with ChangeNotifier {
  final LiveRoomService _service = LiveRoomService();
  final MusicProvider _musicProvider;

  LiveRoom? _currentRoom;
  bool _isHost = false;
  List<ChatMessage> _messages = [];
  List<Map<String, dynamic>> _presenceUsers = [];
  bool _isLoading = false;

  // Listener mock progress state
  Duration listenerDuration = Duration.zero;
  Duration listenerPosition = Duration.zero;
  bool _listenerPlaying = false;
  Timer? _listenerTimer;
  bool _lastBroadcastIsPlaying = false;
  
  void _hostStateListener() {
    if (!_isHost) return;
    if (_musicProvider.isPlaying != _lastBroadcastIsPlaying) {
      _lastBroadcastIsPlaying = _musicProvider.isPlaying;
      _service.broadcastPlayerState(
        _lastBroadcastIsPlaying ? 'play' : 'pause',
        position: _musicProvider.position,
        duration: _musicProvider.duration,
      );
    }
  }

  double get listenerProgress => listenerDuration.inMilliseconds > 0 
      ? listenerPosition.inMilliseconds / listenerDuration.inMilliseconds 
      : 0.0;

  StreamSubscription? _chatSub;
  StreamSubscription? _playerStateSub;
  StreamSubscription? _presenceSub;
  StreamSubscription? _syncReqSub;
  StreamSubscription? _roomClosedSub;

  StreamSubscription? _mpPlaySub;
  StreamSubscription? _mpSeekSub;
  StreamSubscription? _mpSongSub;

  // Stream for UI notifications
  final StreamController<String> _notificationController = StreamController<String>.broadcast();
  Stream<String> get notificationStream => _notificationController.stream;

  LiveRoomProvider(this._musicProvider) {
    _chatSub = _service.chatStream.listen((msg) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && msg.userId == user.id) {
        // Already added locally during send
        return;
      }
      _messages.add(msg);
      notifyListeners();
    });

    _roomClosedSub = _service.roomClosedStream.listen((_) async {
      if (!_isHost && _currentRoom != null) {
        _notificationController.add('Комната закрыта хостом');
        await leaveRoom();
      }
    });

    _presenceSub = _service.presenceStream.listen((users) {
      _presenceUsers = users;
      notifyListeners();
    });

    // Listener receives player state from host
    _playerStateSub = _service.playerStateStream.listen((payload) {
      if (_isHost) return;

      final action = payload['action'];
      debugPrint('LiveRoom Provider: action=$action isHost=$_isHost');

      if (payload['duration_ms'] != null && payload['duration_ms'] > 0) {
        listenerDuration = Duration(milliseconds: payload['duration_ms']);
      }

      if (action == 'change_song') {
        final songMap = payload['song'] ?? payload['payload']?['song'];
        if (songMap != null) {
          try {
            final song = SongModel.fromMap(Map<String, dynamic>.from(songMap));
            
            // Start local playback attempt
            _musicProvider.playSong(song);
            
            // Sync mock state
            _listenerPlaying = true;
            if (listenerDuration == Duration.zero && song.duration.inMilliseconds > 0) {
              listenerDuration = song.duration;
            }
            
            if (payload['position_ms'] != null) {
              listenerPosition = Duration(milliseconds: payload['position_ms']);
              Future.delayed(const Duration(milliseconds: 800), () {
                _musicProvider.seekTo(listenerPosition);
              });
            } else {
              listenerPosition = Duration.zero;
            }
            _startListenerTimer();
            notifyListeners();
          } catch (e) {
            debugPrint('LiveRoom: error parsing song: $e');
          }
        }
      } else if (action == 'play') {
        _listenerPlaying = true;
        if (payload['position_ms'] != null) {
          listenerPosition = Duration(milliseconds: payload['position_ms']);
          _musicProvider.seekTo(listenerPosition);
        }
        _startListenerTimer();
        notifyListeners();
        _musicProvider.forcePlay();
      } else if (action == 'pause') {
        _listenerPlaying = false;
        if (payload['position_ms'] != null) {
          listenerPosition = Duration(milliseconds: payload['position_ms']);
          _musicProvider.seekTo(listenerPosition);
        }
        _stopListenerTimer();
        notifyListeners();
        _musicProvider.forcePause();
      } else if (action == 'seek') {
        if (payload['position_ms'] != null) {
          listenerPosition = Duration(milliseconds: payload['position_ms']);
          _musicProvider.seekTo(listenerPosition);
          notifyListeners();
        }
      }
    });

    // Host handles sync requests from listeners
    _syncReqSub = _service.syncRequestStream.listen((_) {
      if (_isHost) {
        debugPrint('LiveRoom: received sync request, broadcasting state');
        _broadcastCurrentState();
      }
    });
  }

  LiveRoom? get currentRoom => _currentRoom;
  bool get isHost => _isHost;
  List<ChatMessage> get messages => _messages;
  List<Map<String, dynamic>> get presenceUsers => _presenceUsers;
  bool get isLoading => _isLoading;

  Future<void> createAndJoinRoom(String name) async {
    _isLoading = true;
    notifyListeners();

    try {
      final room = await _service.createRoom(name, _musicProvider.currentSong);
      _currentRoom = room;
      _isHost = true;
      _messages.clear();

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');
      final profile = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      await _service.joinRoomChannel(
        room.id,
        userId: user.id,
        username: profile?['username'] ?? 'Host',
        avatarUrl: profile?['profile_image'],
      );

      _setupHostBroadcasting();
    } catch (e) {
      debugPrint('Error creating room: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> joinRoom(LiveRoom room) async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentRoom = room;
      _messages.clear();

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      // Auto-detect if this user is actually the host
      _isHost = (room.hostId == user.id);
      debugPrint('LiveRoom: joining room, isHost=$_isHost (userId=${user.id}, hostId=${room.hostId})');

      final profile = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      await _service.joinRoomChannel(
        room.id,
        userId: user.id,
        username: profile?['username'] ?? (_isHost ? 'Host' : 'Listener'),
        avatarUrl: profile?['profile_image'],
      );

      if (_isHost) {
        _setupHostBroadcasting();
        // Broadcast current state immediately for any existing listeners
        Future.delayed(const Duration(milliseconds: 800), _broadcastCurrentState);
      } else {
        _cancelHostBroadcasting();
        // Request current state from host
        Future.delayed(const Duration(milliseconds: 1500), () {
          debugPrint('LiveRoom: sending request_sync to host');
          _service.broadcastRequestSync();
        });
      }
    } catch (e) {
      debugPrint('Error joining room: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> leaveRoom() async {
    if (_currentRoom != null && _isHost) {
      try {
        await _service.broadcastRoomClosed();
      } catch (_) {}
      await _service.deleteRoom(_currentRoom!.id);
    }
    try {
      _stopListenerTimer();
      await _service.leaveRoom();
      _cancelHostBroadcasting();
    } catch (_) {}
    _currentRoom = null;
    _isHost = false;
    _messages.clear();
    _presenceUsers.clear();
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final profile = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    final username = profile?['username'] ?? 'User';
    final avatarUrl = profile?['profile_image'];

    // Add locally immediately so sender sees it
    _messages.add(ChatMessage(
      userId: user.id,
      username: username,
      avatarUrl: avatarUrl,
      text: text,
      timestamp: DateTime.now(),
    ));
    notifyListeners();

    await _service.broadcastChatMessage(
      text,
      userId: user.id,
      username: username,
      avatarUrl: avatarUrl,
    );
  }

  Future<void> requestSync() async {
    if (!_isHost) {
      debugPrint('LiveRoom: manually requesting sync');
      await _service.broadcastRequestSync();
    }
  }

  void _setupHostBroadcasting() {
    _mpSeekSub?.cancel();
    _mpSongSub?.cancel();
    _musicProvider.removeListener(_hostStateListener);

    _musicProvider.addListener(_hostStateListener);

    _mpSeekSub = _musicProvider.seekEvents.listen((position) {
      _service.broadcastPlayerState('seek', position: position, duration: _musicProvider.duration);
    });

    _mpSongSub = _musicProvider.songChangeEvents.listen((song) async {
      if (_currentRoom != null) {
        await _service.updateRoomSong(_currentRoom!.id, song);
      }
      _service.broadcastPlayerState(
        'change_song',
        song: song,
        position: _musicProvider.position,
        duration: _musicProvider.duration,
      );
    });
  }

  void _broadcastCurrentState() {
    final song = _musicProvider.currentSong;
    if (song == null) return;
    _service.broadcastPlayerState(
      'change_song',
      song: song,
      position: _musicProvider.position,
      duration: _musicProvider.duration,
    );
    Future.delayed(const Duration(milliseconds: 400), () {
      _service.broadcastPlayerState(
        _musicProvider.isPlaying ? 'play' : 'pause',
        position: _musicProvider.position,
        duration: _musicProvider.duration,
      );
    });
  }

  void _startListenerTimer() {
    _listenerTimer?.cancel();
    if (!_listenerPlaying) return;
    
    _listenerTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_listenerPlaying && listenerPosition < listenerDuration) {
        listenerPosition += const Duration(milliseconds: 500);
        if (listenerPosition > listenerDuration) {
          listenerPosition = listenerDuration;
        }
        notifyListeners();
      }
    });
  }

  void _stopListenerTimer() {
    _listenerTimer?.cancel();
    _listenerTimer = null;
  }

  void _cancelHostBroadcasting() {
    _musicProvider.removeListener(_hostStateListener);
    _mpSeekSub?.cancel();
    _mpSongSub?.cancel();
    _mpPlaySub = null;
    _mpSeekSub = null;
    _mpSongSub = null;
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    _playerStateSub?.cancel();
    _presenceSub?.cancel();
    _syncReqSub?.cancel();
    _roomClosedSub?.cancel();
    _notificationController.close();
    _cancelHostBroadcasting();
    super.dispose();
  }
}
