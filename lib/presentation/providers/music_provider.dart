import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/song_model.dart';
import '../../data/models/supabase_song_model.dart';
import '../../data/services/artist_analytics_service.dart';
import 'dart:async';
import '../../data/services/listening_analytics_service.dart';
import '../../data/services/supabase_database_service.dart';
import '../../data/services/friend_activity_service.dart';

class MusicProvider with ChangeNotifier, WidgetsBindingObserver {
  AudioPlayer _audioPlayer = AudioPlayer();
  final SupabaseDatabaseService _supabaseDbService = SupabaseDatabaseService();
  final ListeningAnalyticsService _analyticsService =
      ListeningAnalyticsService.instance;
  final FriendActivityService _friendActivityService = FriendActivityService();
  Timer? _heartbeatTimer;
  StreamSubscription<AuthState>? _authSubscription;

  SongModel? _currentSong;
  List<SongModel> _playlist = [];
  List<SongModel> _recentlyPlayed = []; // Recently played songs
  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isShuffleEnabled = false;
  RepeatMode _repeatMode = RepeatMode.off;
  int _repeatCount = 0;
  bool _isManualTransition = false;
  int _lastIndex = -1;

  final _seekEventController = StreamController<Duration>.broadcast();
  final _songChangeController = StreamController<SongModel>.broadcast();
  final _playStateController = StreamController<bool>.broadcast();

  Stream<Duration> get seekEvents => _seekEventController.stream;
  Stream<SongModel> get songChangeEvents => _songChangeController.stream;
  Stream<bool> get playStateEvents => _playStateController.stream;

  // Getters
  SongModel? get currentSong => _currentSong;
  List<SongModel> get playlist => _playlist;
  List<SongModel> get recentlyPlayed => _recentlyPlayed;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  Duration get duration => _duration;
  Duration get position => _position;
  bool get isShuffleEnabled => _isShuffleEnabled;
  RepeatMode get repeatMode => _repeatMode;

  double get progress {
    if (_duration.inMilliseconds == 0) return 0.0;
    return _position.inMilliseconds / _duration.inMilliseconds;
  }

  MusicProvider() {
    WidgetsBinding.instance.addObserver(this);
    _initializePlayer();
    
    // Check if already logged in (initial session might have already fired)
    if (Supabase.instance.client.auth.currentSession != null) {
      _startHeartbeat();
    }

    // Listen to auth changes to start heartbeat only when logged in
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
        _startHeartbeat();
      } else {
        _heartbeatTimer?.cancel();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _friendActivityService.updateActivity(_currentSong, _isPlaying, isOnline: true);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _friendActivityService.updateActivity(_currentSong, _isPlaying, isOnline: false);
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    // Send heartbeat immediately on startup
    _friendActivityService.updateActivity(_currentSong, _isPlaying);
    
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      // Periodic heartbeat to show the user is online even if not changing songs
      _friendActivityService.updateActivity(_currentSong, _isPlaying);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _heartbeatTimer?.cancel();
    _seekEventController.close();
    _songChangeController.close();
    _playStateController.close();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _recreatePlayer() {
    debugPrint('MusicProvider: Recreating audio player due to fatal error');
    try {
      _audioPlayer.dispose();
    } catch (_) {}
    _audioPlayer = AudioPlayer();
    _initializePlayer();
  }

  void _initializePlayer() {
    // Listen to player state changes
    _audioPlayer.playerStateStream.listen((state) async {
      _isPlaying = state.playing;
      _isLoading =
          state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;
      
      _friendActivityService.updateActivity(_currentSong, _isPlaying);

      // Handle song completion for custom repeat modes
      if (state.processingState == ProcessingState.completed) {
        if (_repeatMode == RepeatMode.once) {
          if (_repeatCount > 0) {
            _repeatCount--;
            await _audioPlayer.seek(Duration.zero);
            await _audioPlayer.play();
          } else {
            // Once finished, reset count and move to next song
            _repeatCount = 1;
            if (_playlist.isNotEmpty && _currentIndex < _playlist.length - 1) {
              skipToNext();
            } else if (_playlist.isNotEmpty) {
              // End of playlist -> Loop to first
              await _audioPlayer.seek(Duration.zero, index: 0);
              await _audioPlayer.play();
            }
          }
        } else if (_repeatMode == RepeatMode.off) {
          if (_playlist.isNotEmpty && _currentIndex < _playlist.length - 1) {
            skipToNext();
          } else if (_playlist.isNotEmpty) {
            // End of playlist -> Loop to first
            await _audioPlayer.seek(Duration.zero, index: 0);
            await _audioPlayer.play();
          }
        }
      }
      notifyListeners();
    }, onError: (e) {
      debugPrint('MusicProvider playerStateStream error: $e');
    });

    // Listen to duration changes
    _audioPlayer.durationStream.listen((duration) {
      _duration = duration ?? Duration.zero;
      notifyListeners();
    }, onError: (_) {});

    // Listen to position changes
    _audioPlayer.positionStream.listen((position) {
      _position = position;
      notifyListeners();
    }, onError: (_) {});

    // Listen to sequence state changes (for playlist navigation)
    _audioPlayer.sequenceStateStream.listen((sequenceState) async {
      if (sequenceState != null) {
        final newIndex = sequenceState.currentIndex;
        
        // Custom repeat-once behavior: play twice, then skip to next
        if (_lastIndex != -1 && newIndex != _lastIndex && newIndex < _playlist.length) {
          if (!_isManualTransition) {
            if (_repeatMode == RepeatMode.once && _repeatCount > 0) {
              _repeatCount--;
              final prevIndex = _lastIndex;
              _lastIndex = newIndex; // Prevent infinite loops
              await _audioPlayer.seek(Duration.zero, index: prevIndex);
              return;
            }
          }
        }
        
        _isManualTransition = false;
        _lastIndex = newIndex;
        _currentIndex = newIndex;
        
        if (_currentIndex < _playlist.length) {
          final newSong = _playlist[_currentIndex];
          // Check if song actually changed to avoid redundant updates
          if (_currentSong?.id != newSong.id) {
            _currentSong = newSong;
            _repeatCount = 1; // Reset repeat count for the new song
            _addToRecentlyPlayed(newSong);
            await _analyticsService.recordPlay(newSong);
            if (newSong.backendId != null) {
              await ArtistAnalyticsService.recordListen(newSong.backendId!);
            }
            _supabaseDbService.addToHistory(newSong, 0);
            _songChangeController.add(newSong);
            _friendActivityService.updateActivity(newSong, _isPlaying);
            notifyListeners();
          }
        }
      }
    }, onError: (_) {});
  }

  Future<void> playSong(SongModel song) async {
    try {
      _isManualTransition = true;
      _lastIndex = 0;
      _currentSong = song;
      _playlist = [song];
      _currentIndex = 0;
      _repeatCount = 1;
      notifyListeners();

      // Use the song's actual audio URL, fallback to demo if null
      final url =
          song.audioUrl ??
          'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';
      debugPrint('MusicProvider: Playing song "${song.title}" from URL: $url');

      try {
        await _audioPlayer.setUrl(url);
        await _audioPlayer.play();
      } catch (e) {
        if (e.toString().contains('MissingPluginException')) {
          _recreatePlayer();
          await _audioPlayer.setUrl(url);
          await _audioPlayer.play();
        } else {
          rethrow;
        }
      }

      // Add to recently played (avoid duplicates, keep at front)
      _addToRecentlyPlayed(song);
      await _analyticsService.recordPlay(song);
      if (song.backendId != null) {
        await ArtistAnalyticsService.recordListen(song.backendId!);
      }

      // Record to listening history in Supabase
      _supabaseDbService.addToHistory(song, 0);
      _songChangeController.add(song);
      _playStateController.add(true);
    } catch (e) {
      debugPrint('Error playing song: $e');
    }
  }

  void _addToRecentlyPlayed(SongModel song) {
    // Remove if already exists
    _recentlyPlayed.removeWhere(
      (s) =>
          s.id == song.id || (s.title == song.title && s.artist == song.artist),
    );

    // Add to front
    _recentlyPlayed.insert(0, song);

    // Keep only last 10 songs
    if (_recentlyPlayed.length > 10) {
      _recentlyPlayed = _recentlyPlayed.sublist(0, 10);
    }

    notifyListeners();
  }

  Future<void> playPlaylist(List<SongModel> songs, int startIndex) async {
    try {
      _isManualTransition = true;
      _lastIndex = startIndex;
      _playlist = songs;
      _currentIndex = startIndex;
      _currentSong = songs[startIndex];
      _repeatCount = 1;

      // Add to recently played and history for the starting song
      // (The listener handles subsequent songs, but avoids the first one if _currentSong is already set)
      _addToRecentlyPlayed(_currentSong!);
      await _analyticsService.recordPlay(_currentSong!);
      if (_currentSong!.backendId != null) {
        await ArtistAnalyticsService.recordListen(_currentSong!.backendId!);
      }
      _supabaseDbService.addToHistory(_currentSong!, 0);

      notifyListeners();

      // Create audio sources for the playlist using actual URLs
      final audioSources = songs.map((song) {
        final url =
            song.audioUrl ??
            'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';
        return AudioSource.uri(Uri.parse(url));
      }).toList();

      try {
        await _audioPlayer.setAudioSource(
          ConcatenatingAudioSource(children: audioSources),
          initialIndex: startIndex,
        );
        await _audioPlayer.play();
      } catch (e) {
        if (e.toString().contains('MissingPluginException') || e.toString().contains('-11800')) {
          _recreatePlayer();
          try {
            await _audioPlayer.setAudioSource(
              ConcatenatingAudioSource(children: audioSources),
              initialIndex: startIndex,
            );
            await _audioPlayer.play();
          } catch (_) {}
        } else {
          rethrow;
        }
      }
      
      _songChangeController.add(songs[startIndex]);
      _playStateController.add(true);
    } catch (e) {
      debugPrint('Error playing playlist: $e');
    }
  }

  /// Play a song from Supabase Storage
  Future<void> playSupabaseSong(SupabaseSong supabaseSong) async {
    try {
      // Convert SupabaseSong to SongModel for consistent player state
      final song = SongModel(
        id: supabaseSong.id.hashCode,
        title: supabaseSong.title,
        artist: supabaseSong.artist,
        album: 'Supabase',
        albumArt: supabaseSong.coverUrl,
        audioUrl: supabaseSong.audioUrl,
        duration: Duration.zero, // Will be updated when loaded
        genre: 'Unknown',
        createdAt: supabaseSong.uploadedAt,
      );

      _isManualTransition = true;
      _lastIndex = 0;
      _currentSong = song;
      _playlist = [song];
      _currentIndex = 0;
      _repeatCount = 1;
      notifyListeners();

      // Play from Supabase URL
      try {
        await _audioPlayer.setUrl(supabaseSong.audioUrl);
        await _audioPlayer.play();
      } catch (e) {
        if (e.toString().contains('MissingPluginException') || e.toString().contains('-11800')) {
          _recreatePlayer();
          try {
            await _audioPlayer.setUrl(supabaseSong.audioUrl);
            await _audioPlayer.play();
          } catch (_) {}
        } else {
          rethrow;
        }
      }

      // Add to recently played (avoid duplicates, keep at front)
      _addToRecentlyPlayed(song);
      await _analyticsService.recordPlay(song);
      if (song.backendId != null) {
        await ArtistAnalyticsService.recordListen(song.backendId!);
      }
      // Record to listening history in Supabase
      _supabaseDbService.addToHistory(song, 0);
    } catch (e) {
      debugPrint('Error playing Supabase song: $e');
    }
  }

  Future<void> forcePlay() async {
    try {
      await _audioPlayer.play();
      _playStateController.add(true);
    } catch (e) {
      debugPrint('Error forcing play: $e');
      if (e.toString().contains('MissingPluginException')) {
        _recreatePlayer();
        if (_currentSong != null) {
          try {
            await _audioPlayer.setUrl(_currentSong!.audioUrl ?? '');
            await _audioPlayer.play();
            _playStateController.add(true);
          } catch (_) {}
        }
      }
    }
  }

  Future<void> forcePause() async {
    try {
      await _audioPlayer.pause();
      _playStateController.add(false);
    } catch (e) {
      debugPrint('Error forcing pause: $e');
    }
  }

  Future<void> togglePlayPause() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        _playStateController.add(false);
      } else {
        await _audioPlayer.play();
        _playStateController.add(true);
      }
    } catch (e) {
      debugPrint('Error toggling play/pause: $e');
      if (e.toString().contains('MissingPluginException')) {
        _recreatePlayer();
        // Since we lost state, try to re-load current song
        if (_currentSong != null) {
          try {
            await _audioPlayer.setUrl(_currentSong!.audioUrl ?? '');
            await _audioPlayer.play();
            _playStateController.add(true);
          } catch (_) {}
        }
      }
    }
  }

  Future<void> seekTo(Duration position) async {
    try {
      await _audioPlayer.seek(position);
      _seekEventController.add(position);
    } catch (e) {
      debugPrint('Error seeking: $e');
      if (e.toString().contains('MissingPluginException')) {
        _recreatePlayer();
      }
    }
  }

  Future<void> skipToNext() async {
    try {
      _isManualTransition = true;
      _repeatCount = 1; // Reset repeat count for the new song
      if (_audioPlayer.hasNext) {
        await _audioPlayer.seekToNext();
      } else if (_playlist.isNotEmpty) {
        // If at the end of playlist, go to first song if repeat is enabled
        if (_repeatMode == RepeatMode.infinite) {
          await _audioPlayer.seek(Duration.zero, index: 0);
        }
      }
    } catch (e) {
      debugPrint('Error skipping to next: $e');
      if (e.toString().contains('MissingPluginException')) {
        _recreatePlayer();
      }
    }
  }

  Future<void> skipToPrevious() async {
    try {
      _isManualTransition = true;
      _repeatCount = 1; // Reset repeat count for the new song
      if (_audioPlayer.hasPrevious) {
        await _audioPlayer.seekToPrevious();
      } else if (_playlist.isNotEmpty && _repeatMode == RepeatMode.infinite) {
        // If at the beginning of playlist, go to last song if repeat is enabled
        await _audioPlayer.seek(Duration.zero, index: _playlist.length - 1);
      }
    } catch (e) {
      debugPrint('Error skipping to previous: $e');
      if (e.toString().contains('MissingPluginException')) {
        _recreatePlayer();
      }
    }
  }

  void toggleShuffle() {
    _isShuffleEnabled = !_isShuffleEnabled;
    _audioPlayer.setShuffleModeEnabled(_isShuffleEnabled);
    notifyListeners();
  }

  void toggleRepeat() {
    switch (_repeatMode) {
      case RepeatMode.off:
        _repeatMode = RepeatMode.once;
        _repeatCount = 1; // Will repeat one more time
        _audioPlayer.setLoopMode(LoopMode.off); // We handle this manually
        break;
      case RepeatMode.once:
        _repeatMode = RepeatMode.infinite;
        _repeatCount = -1; // Infinite
        _audioPlayer.setLoopMode(LoopMode.one);
        break;
      case RepeatMode.infinite:
        _repeatMode = RepeatMode.off;
        _repeatCount = 0;
        _audioPlayer.setLoopMode(LoopMode.off);
        break;
    }
    notifyListeners();
  }

  double _volume = 0.7;
  double get volume => _volume;

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _audioPlayer.setVolume(_volume);
    notifyListeners();
  }

  Future<void> toggleFavorite() async {
    if (_currentSong != null) {
      try {
        // This would typically involve updating the database
        // For now, we'll just toggle the local state
        _currentSong = _currentSong!.copyWith(
          isFavorite: !_currentSong!.isFavorite,
        );
        notifyListeners();
      } catch (e) {
        debugPrint('Error toggling favorite: $e');
      }
    }
  }

  /// Reorder a song in the queue from [oldIndex] to [newIndex].
  /// Indices are relative to the upcoming songs list (starting after currentIndex).
  void reorderQueue(int oldIndex, int newIndex) {
    // Convert relative indices to absolute playlist indices
    final absoluteOldIndex = _currentIndex + 1 + oldIndex;
    final absoluteNewIndex = _currentIndex + 1 + (newIndex > oldIndex ? newIndex - 1 : newIndex);

    if (absoluteOldIndex < 0 || absoluteOldIndex >= _playlist.length) return;
    if (absoluteNewIndex < 0 || absoluteNewIndex >= _playlist.length) return;

    final song = _playlist.removeAt(absoluteOldIndex);
    _playlist.insert(absoluteNewIndex, song);
    notifyListeners();
  }

  /// Remove a song from the queue at [relativeIndex] (relative to upcoming songs).
  void removeFromQueue(int relativeIndex) {
    final absoluteIndex = _currentIndex + 1 + relativeIndex;
    if (absoluteIndex < 0 || absoluteIndex >= _playlist.length) return;
    _playlist.removeAt(absoluteIndex);
    notifyListeners();
  }

}
enum RepeatMode { off, once, infinite }
