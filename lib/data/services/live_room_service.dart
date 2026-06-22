import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/song_model.dart';

class LiveRoom {
  final String id;
  final String name;
  final String hostId;
  final String? hostName;
  final String? hostAvatar;
  final SongModel? currentSong;
  final DateTime createdAt;
  final int listenersCount;

  LiveRoom({
    required this.id,
    required this.name,
    required this.hostId,
    this.hostName,
    this.hostAvatar,
    this.currentSong,
    required this.createdAt,
    this.listenersCount = 0,
  });

  factory LiveRoom.fromMap(Map<String, dynamic> map) {
    SongModel? song;
    if (map['current_song'] != null) {
      try {
        final songMap = map['current_song'] is String 
            ? jsonDecode(map['current_song']) 
            : map['current_song'];
        song = SongModel.fromMap(songMap);
      } catch (_) {}
    }

    return LiveRoom(
      id: map['id'],
      name: map['name'] ?? 'Live Room',
      hostId: map['host_id'],
      hostName: map['_host_name'] as String?,
      hostAvatar: map['_host_avatar'] as String?,
      currentSong: song,
      createdAt: DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now(),
    );
  }
}

class ChatMessage {
  final String userId;
  final String username;
  final String? avatarUrl;
  final String text;
  final DateTime timestamp;

  ChatMessage({
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.text,
    required this.timestamp,
  });
}

class LiveRoomService {
  final SupabaseClient _client = Supabase.instance.client;
  SupabaseClient get client => _client;
  RealtimeChannel? _channel;

  // Streams
  final _chatController = StreamController<ChatMessage>.broadcast();
  final _playerStateController = StreamController<Map<String, dynamic>>.broadcast();
  final _presenceController = StreamController<List<Map<String, dynamic>>>.broadcast();
  final _syncRequestController = StreamController<bool>.broadcast();
  final _roomClosedController = StreamController<bool>.broadcast();

  Stream<ChatMessage> get chatStream => _chatController.stream;
  Stream<Map<String, dynamic>> get playerStateStream => _playerStateController.stream;
  Stream<List<Map<String, dynamic>>> get presenceStream => _presenceController.stream;
  Stream<bool> get syncRequestStream => _syncRequestController.stream;
  Stream<bool> get roomClosedStream => _roomClosedController.stream;

  // DB Methods
  Future<List<LiveRoom>> getActiveRooms() async {
    final response = await _client
        .from('live_rooms')
        .select()
        .order('created_at', ascending: false);

    final rooms = <LiveRoom>[];
    for (final row in (response as List)) {
      final map = row as Map<String, dynamic>;
      // Fetch host profile separately
      try {
        final profile = await _client
            .from('profiles')
            .select('username, profile_image')
            .eq('id', map['host_id'])
            .maybeSingle();
        if (profile != null) {
          map['_host_name'] = profile['username'];
          map['_host_avatar'] = profile['profile_image'];
        }
      } catch (_) {}
      rooms.add(LiveRoom.fromMap(map));
    }
    return rooms;
  }

  Future<LiveRoom> createRoom(String name, SongModel? initialSong) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final data = {
      'name': name,
      'host_id': user.id,
      'current_song': initialSong?.toMap(),
    };

    final response = await _client.from('live_rooms').insert(data).select().single();
    // Fetch host profile
    final map = Map<String, dynamic>.from(response);
    try {
      final profile = await _client
          .from('profiles')
          .select('username, profile_image')
          .eq('id', user.id)
          .maybeSingle();
      if (profile != null) {
        map['_host_name'] = profile['username'];
        map['_host_avatar'] = profile['profile_image'];
      }
    } catch (_) {}
    return LiveRoom.fromMap(map);
  }

  Future<void> updateRoomSong(String roomId, SongModel song) async {
    await _client.from('live_rooms').update({
      'current_song': song.toMap(),
    }).eq('id', roomId);
  }

  Future<void> deleteRoom(String roomId) async {
    await _client.from('live_rooms').delete().eq('id', roomId);
  }

  // Realtime Channel Methods
  Future<void> joinRoomChannel(String roomId, {required String userId, required String username, String? avatarUrl}) async {
    await _channel?.unsubscribe();
    
    _channel = _client.channel('room:$roomId');

    _channel!
      ..onBroadcast(event: 'player_state', callback: (payload) {
        debugPrint('LiveRoom: received player_state: $payload');
        // Supabase passes payload directly (not wrapped)
        final data = payload['payload'] ?? payload;
        if (data is Map<String, dynamic>) {
          _playerStateController.add(data);
        }
      })
      ..onBroadcast(event: 'chat_message', callback: (payload) {
        debugPrint('LiveRoom: received chat_message: $payload');
        final data = (payload['payload'] ?? payload) as Map<String, dynamic>;
        _chatController.add(ChatMessage(
          userId: data['user_id'] ?? '',
          username: data['username'] ?? 'User',
          avatarUrl: data['avatar_url'],
          text: data['text'] ?? '',
          timestamp: DateTime.tryParse(data['timestamp'].toString()) ?? DateTime.now(),
        ));
      })
      ..onBroadcast(event: 'request_sync', callback: (payload) {
        debugPrint('LiveRoom: received request_sync');
        _syncRequestController.add(true);
      })
      ..onBroadcast(event: 'room_closed', callback: (payload) {
        debugPrint('LiveRoom: received room_closed');
        _roomClosedController.add(true);
      })
      ..onPresenceSync((payload) {
        final state = _channel!.presenceState();
        final List<Map<String, dynamic>> users = [];
        for (final singleState in state) {
          for (final presence in singleState.presences) {
            users.add(presence.payload);
          }
        }
        _presenceController.add(users);
      });

    await _channel!.subscribe((status, error) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await _channel!.track({
          'user_id': userId,
          'username': username,
          'avatar_url': avatarUrl,
          'joined_at': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  Future<void> leaveRoom() async {
    await _channel?.unsubscribe();
    _channel = null;
  }

  // Broadcasting Actions
  Future<void> broadcastPlayerState(String action, {Duration? position, Duration? duration, SongModel? song}) async {
    if (_channel == null) return;
    
    final payload = <String, dynamic>{
      'action': action, // 'play', 'pause', 'seek', 'change_song'
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    if (position != null) {
      payload['position_ms'] = position.inMilliseconds;
    }
    if (duration != null) {
      payload['duration_ms'] = duration.inMilliseconds;
    }
    if (song != null) {
      payload['song'] = song.toMap();
    }

    await _channel!.sendBroadcastMessage(
      event: 'player_state',
      payload: payload,
    );
  }

  Future<void> broadcastChatMessage(String text, {required String userId, required String username, String? avatarUrl}) async {
    if (_channel == null) return;
    
    final payload = {
      'user_id': userId,
      'username': username,
      'avatar_url': avatarUrl,
      'text': text,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await _channel!.sendBroadcastMessage(
      event: 'chat_message',
      payload: payload,
    );
  }

  Future<void> broadcastRequestSync() async {
    if (_channel == null) return;
    await _channel!.sendBroadcastMessage(
      event: 'request_sync',
      payload: {'ts': DateTime.now().toIso8601String()},
    );
  }

  Future<void> broadcastRoomClosed() async {
    if (_channel == null) return;
    await _channel!.sendBroadcastMessage(
      event: 'room_closed',
      payload: {'ts': DateTime.now().toIso8601String()},
    );
  }

  void dispose() {
    _chatController.close();
    _playerStateController.close();
    _presenceController.close();
    _syncRequestController.close();
    _roomClosedController.close();
  }
}
