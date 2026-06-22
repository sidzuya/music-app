import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../data/models/song_model.dart';
import '../../data/models/playlist_model.dart';
import '../../data/services/listening_analytics_service.dart';
import '../../data/services/playlist_remote_writer.dart';
import '../../data/services/supabase_database_service.dart';
import '../../data/services/featured_songs_service.dart';

class PlaylistProvider with ChangeNotifier {
  List<SongModel> _favoriteSongs = [];
  List<PlaylistModel> _playlists = [];
  final Map<int, List<SongModel>> _playlistSongs = {}; // Local ID -> songs
  Map<int, String> _playlistUuidMap = {}; // Local ID -> Supabase UUID
  bool _isLoading = false;
  final bool _useSupabase;

  final PlaylistRemoteWriter _supabaseService;
  final ListeningAnalyticsService _analyticsService =
      ListeningAnalyticsService.instance;

  // Getters
  List<SongModel> get favoriteSongs => _favoriteSongs;
  List<PlaylistModel> get playlists => _playlists;
  bool get isLoading => _isLoading;

  /// [remoteWriter] lets tests inject a fake implementation; in production the
  /// singleton [SupabaseDatabaseService] is used. Set [autoLoad] to `false`
  /// in tests to skip the SharedPreferences / Supabase warm-up.
  PlaylistProvider({
    PlaylistRemoteWriter? remoteWriter,
    bool useSupabase = true,
    bool autoLoad = true,
  })  : _supabaseService = remoteWriter ?? SupabaseDatabaseService(),
        _useSupabase = useSupabase {
    if (autoLoad) {
      _loadData();
    }
  }

  // Load data - tries Supabase first, falls back to SharedPreferences
  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_useSupabase) {
        await _loadFromSupabase();
      }

      // Also load from SharedPreferences as backup/offline cache
      await _loadFromLocal();
    } catch (e) {
      debugPrint('PlaylistProvider._loadData error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadFromSupabase() async {
    try {
      // Load favorites from Supabase
      final supabaseFavorites = await _supabaseService.getFavorites();
      if (supabaseFavorites.isNotEmpty) {
        _favoriteSongs = supabaseFavorites;
        debugPrint(
          'PlaylistProvider: Loaded ${_favoriteSongs.length} favorites from Supabase',
        );
      }

      // Load playlists from Supabase
      final supabasePlaylistsData = await _supabaseService.getPlaylists();
      if (supabasePlaylistsData.isNotEmpty) {
        _playlists = supabasePlaylistsData.map((json) {
          final String uuid = json['id'];
          final int idHash = uuid.hashCode;
          final String userIdStr = json['user_id'] ?? '';

          // Update UUID map
          _playlistUuidMap[idHash] = uuid;

          return PlaylistModel(
            id: idHash,
            name: json['name'] ?? '',
            description: json['description'],
            coverImage: json['cover_url'],
            userId: userIdStr.hashCode,
            createdAt: DateTime.parse(json['created_at']),
            updatedAt: DateTime.parse(json['updated_at']),
            songIds:
                [], // Songs loaded separately via playlist_songs table usually or inferred strings
          );
        }).toList();

        await _savePlaylistUuidMap();
        debugPrint(
          'PlaylistProvider: Loaded ${_playlists.length} playlists from Supabase and updated UUID map',
        );
      }
    } catch (e) {
      debugPrint('PlaylistProvider._loadFromSupabase error: $e');
    }
  }

  Future<void> _loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load favorite songs (if not already loaded from Supabase)
      if (_favoriteSongs.isEmpty) {
        final favoritesJson = prefs.getString('favorite_songs');
        if (favoritesJson != null) {
          final List<dynamic> favoritesList = jsonDecode(favoritesJson);
          _favoriteSongs = favoritesList
              .map((json) => SongModel.fromMap(json))
              .toList();
          debugPrint(
            'PlaylistProvider: Loaded ${_favoriteSongs.length} favorites from local',
          );
          for (var song in _favoriteSongs) {
            debugPrint('  - "${song.title}" audioUrl: ${song.audioUrl}');
          }
        }
      }

      // Load playlists (if not already loaded from Supabase)
      if (_playlists.isEmpty) {
        final playlistsJson = prefs.getString('playlists');
        if (playlistsJson != null) {
          final List<dynamic> playlistsList = jsonDecode(playlistsJson);
          _playlists = playlistsList
              .map((json) => PlaylistModel.fromMap(json))
              .toList();
        }
      }

      // Load playlist songs
      for (var playlist in _playlists) {
        if (playlist.id != null) {
          final songsJson = prefs.getString('playlist_${playlist.id}_songs');
          if (songsJson != null) {
            final List<dynamic> songsList = jsonDecode(songsJson);
            _playlistSongs[playlist.id!] = songsList
                .map((json) => SongModel.fromMap(json))
                .toList();
          }
        }
      }

      // Load UUID map
      await _loadPlaylistUuidMap();

      // Restore covers for all loaded songs
      _restoreCovers();
    } catch (e) {
      debugPrint('PlaylistProvider._loadFromLocal error: $e');
    }
  }

  /// Fetch songs for a collab playlist directly from Supabase into local state
  Future<void> fetchCollabSongs(String supabaseUuid) async {
    if (!_useSupabase) return;
    try {
      var songs = await _supabaseService.getPlaylistSongs(supabaseUuid);
      // Restore album art from featured songs service for songs missing artwork
      final coverService = FeaturedSongsService.instance;
      songs = songs.map((song) {
        if (song.albumArt == null || song.albumArt!.isEmpty) {
          final coverUrl = coverService.getCoverForTitle(song.title);
          if (coverUrl != null) return song.copyWith(albumArt: coverUrl);
        }
        return song;
      }).toList();
      final localId = supabaseUuid.hashCode;
      _playlistSongs[localId] = songs;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching collab songs: $e');
    }
  }

  /// Restore album covers for songs that don't have them
  void _restoreCovers() {
    final coverService = FeaturedSongsService.instance;

    // Restore covers for favorites
    _favoriteSongs = _favoriteSongs.map((song) {
      if (song.albumArt == null || song.albumArt!.isEmpty) {
        final coverUrl = coverService.getCoverForTitle(song.title);
        if (coverUrl != null) {
          return song.copyWith(albumArt: coverUrl);
        }
      }
      return song;
    }).toList();

    // Restore covers for playlist songs
    for (final playlistId in _playlistSongs.keys) {
      _playlistSongs[playlistId] = _playlistSongs[playlistId]!.map((song) {
        if (song.albumArt == null || song.albumArt!.isEmpty) {
          final coverUrl = coverService.getCoverForTitle(song.title);
          if (coverUrl != null) {
            return song.copyWith(albumArt: coverUrl);
          }
        }
        return song;
      }).toList();
    }

    debugPrint('PlaylistProvider: Restored covers for songs');
  }

  // Save favorite songs locally
  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = jsonEncode(
        _favoriteSongs.map((song) => song.toMap()).toList(),
      );
      debugPrint('PlaylistProvider: Saving ${_favoriteSongs.length} favorites');
      for (var song in _favoriteSongs) {
        debugPrint('  - "${song.title}" audioUrl: ${song.audioUrl}');
      }
      await prefs.setString('favorite_songs', favoritesJson);
    } catch (e) {
      debugPrint('Error saving favorites: $e');
    }
  }

  // Save playlists locally
  Future<void> _savePlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final playlistsJson = jsonEncode(
        _playlists.map((playlist) => playlist.toMap()).toList(),
      );
      await prefs.setString('playlists', playlistsJson);
    } catch (e) {
      debugPrint('Error saving playlists: $e');
    }
  }

  // Save playlist songs locally
  Future<void> _savePlaylistSongs(int playlistId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final songs = _playlistSongs[playlistId] ?? [];
      final songsJson = jsonEncode(songs.map((song) => song.toMap()).toList());
      await prefs.setString('playlist_${playlistId}_songs', songsJson);
    } catch (e) {
      debugPrint('Error saving playlist songs: $e');
    }
  }

  // Save playlist UUID map
  Future<void> _savePlaylistUuidMap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mapJson = jsonEncode(
        _playlistUuidMap.map((k, v) => MapEntry(k.toString(), v)),
      );
      await prefs.setString('playlist_uuid_map', mapJson);
    } catch (e) {
      debugPrint('Error saving UUID map: $e');
    }
  }

  // Load playlist UUID map
  Future<void> _loadPlaylistUuidMap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mapJson = prefs.getString('playlist_uuid_map');
      if (mapJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(mapJson);
        _playlistUuidMap = decoded.map(
          (k, v) => MapEntry(int.parse(k), v as String),
        );
      }
    } catch (e) {
      debugPrint('Error loading UUID map: $e');
    }
  }

  // Toggle favorite - syncs with Supabase
  Future<bool> toggleFavorite(SongModel song) async {
    debugPrint(
      'PlaylistProvider.toggleFavorite: "${song.title}" audioUrl: ${song.audioUrl}',
    );
    try {
      final index = _favoriteSongs.indexWhere(
        (s) =>
            s.id == song.id ||
            (s.title == song.title && s.artist == song.artist),
      );

      if (index >= 0) {
        // Remove from favorites
        _favoriteSongs.removeAt(index);
        await _saveFavorites();
        _analyticsService.notifyPreferenceChange();

        // Sync with Supabase
        if (_useSupabase) {
          await _supabaseService.removeFromFavorites(song);
        }

        notifyListeners();
        return false; // Not favorite anymore
      } else {
        // Add to favorites
        _favoriteSongs.add(song.copyWith(isFavorite: true));
        await _saveFavorites();
        _analyticsService.notifyPreferenceChange();

        // Sync with Supabase
        if (_useSupabase) {
          await _supabaseService.addToFavorites(song);
        }

        notifyListeners();
        return true; // Now favorite
      }
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      return false;
    }
  }

  // Check if song is favorite
  bool isFavorite(SongModel song) {
    return _favoriteSongs.any(
      (s) =>
          s.id == song.id || (s.title == song.title && s.artist == song.artist),
    );
  }

  // Create new playlist - syncs with Supabase
  Future<PlaylistModel?> createPlaylist(
    String name,
    String? description,
  ) async {
    try {
      String? supabaseId;

      // Create in Supabase first. If the insert is rejected (missing table,
      // RLS policy, offline, etc.) we must NOT silently create a local-only
      // ghost playlist — otherwise the UI claims success while nothing was
      // persisted. Return null so the caller can surface the real failure.
      if (_useSupabase) {
        supabaseId = await _supabaseService.createPlaylist(name, description);
        debugPrint(
          'PlaylistProvider: Created playlist in Supabase with ID: $supabaseId',
        );
        if (supabaseId == null) {
          debugPrint(
            'PlaylistProvider: Supabase rejected createPlaylist("$name"); '
            'aborting to surface the failure to the UI.',
          );
          return null;
        }
      }

      final localId =
          supabaseId?.hashCode ?? DateTime.now().millisecondsSinceEpoch;

      final newPlaylist = PlaylistModel(
        id: localId,
        name: name,
        description: description,
        userId: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      _playlists.add(newPlaylist);
      _playlistSongs[newPlaylist.id!] = [];

      // Store UUID mapping for Supabase sync
      if (supabaseId != null) {
        _playlistUuidMap[localId] = supabaseId;
        await _savePlaylistUuidMap();
      }

      await _savePlaylists();
      await _savePlaylistSongs(newPlaylist.id!);
      notifyListeners();

      return newPlaylist;
    } catch (e) {
      debugPrint('Error creating playlist: $e');
      return null;
    }
  }

  // Add song to playlist - syncs with Supabase
  Future<bool> addSongToPlaylist(int playlistId, SongModel song) async {
    try {
      final songs = _playlistSongs[playlistId] ?? [];

      // Check if song already exists in playlist
      final exists = songs.any(
        (s) =>
            s.id == song.id ||
            (s.title == song.title && s.artist == song.artist),
      );

      if (!exists) {
        songs.add(song);
        _playlistSongs[playlistId] = songs;

        // Update playlist's updatedAt and songIds
        final playlistIndex = _playlists.indexWhere((p) => p.id == playlistId);
        if (playlistIndex >= 0) {
          final playlist = _playlists[playlistIndex];
          final updatedSongIds = List<int>.from(playlist.songIds);
          if (song.id != null) {
            updatedSongIds.add(song.id!);
          }
          _playlists[playlistIndex] = playlist.copyWith(
            updatedAt: DateTime.now(),
            songIds: updatedSongIds,
          );
          await _savePlaylists();
        }

        // Sync with Supabase
        if (_useSupabase) {
          final supabaseUuid = _playlistUuidMap[playlistId];
          if (supabaseUuid != null) {
            await _supabaseService.addSongToPlaylist(supabaseUuid, song);
            debugPrint(
              'PlaylistProvider: Synced song "${song.title}" to Supabase playlist',
            );
          } else {
            debugPrint(
              'PlaylistProvider: No Supabase UUID for playlist $playlistId',
            );
          }
        }

        await _savePlaylistSongs(playlistId);
        notifyListeners();
        return true;
      }

      return false; // Song already in playlist
    } catch (e) {
      debugPrint('Error adding song to playlist: $e');
      return false;
    }
  }

  // Remove song from playlist - syncs with Supabase
  Future<bool> removeSongFromPlaylist(int playlistId, SongModel song) async {
    try {
      final songs = _playlistSongs[playlistId] ?? [];
      final initialLength = songs.length;

      songs.removeWhere(
        (s) =>
            s.id == song.id ||
            (s.title == song.title && s.artist == song.artist),
      );

      if (songs.length < initialLength) {
        _playlistSongs[playlistId] = songs;

        // Update playlist's updatedAt and songIds
        final playlistIndex = _playlists.indexWhere((p) => p.id == playlistId);
        if (playlistIndex >= 0) {
          final playlist = _playlists[playlistIndex];
          _playlists[playlistIndex] = playlist.copyWith(
            updatedAt: DateTime.now(),
            songIds: songs
                .where((s) => s.id != null)
                .map((s) => s.id!)
                .toList(),
          );
          await _savePlaylists();
        }

        await _savePlaylistSongs(playlistId);
        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error removing song from playlist: $e');
      return false;
    }
  }

  // Get songs in playlist
  List<SongModel> getPlaylistSongs(int playlistId) {
    return _playlistSongs[playlistId] ?? [];
  }

  // Get Supabase UUID for a local playlist ID
  String? getPlaylistUuid(int playlistId) {
    return _playlistUuidMap[playlistId];
  }

  // Delete playlist - syncs with Supabase
  Future<bool> deletePlaylist(int playlistId) async {
    try {
      // Sync with Supabase first
      if (_useSupabase) {
        final supabaseUuid = _playlistUuidMap[playlistId];
        if (supabaseUuid != null) {
          await _supabaseService.deletePlaylist(supabaseUuid);
        }
      }

      _playlists.removeWhere((p) => p.id == playlistId);
      _playlistSongs.remove(playlistId);
      _playlistUuidMap.remove(playlistId);

      await _savePlaylists();
      await _savePlaylistUuidMap();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('playlist_${playlistId}_songs');

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting playlist: $e');
      return false;
    }
  }

  // Rename playlist
  Future<bool> renamePlaylist(int playlistId, String newName) async {
    try {
      final playlistIndex = _playlists.indexWhere((p) => p.id == playlistId);
      if (playlistIndex >= 0) {
        final oldPlaylist = _playlists[playlistIndex];
        _playlists[playlistIndex] = oldPlaylist.copyWith(
          name: newName,
          updatedAt: DateTime.now(),
        );
        await _savePlaylists();

        // Sync with Supabase
        if (_useSupabase) {
          final supabaseUuid = _playlistUuidMap[playlistId];
          if (supabaseUuid != null) {
            await _supabaseService.updatePlaylist(
              supabaseUuid,
              newName,
              oldPlaylist.description,
            );
          }
        }

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error renaming playlist: $e');
      return false;
    }
  }

  // Update playlist (name and description)
  Future<bool> updatePlaylist(PlaylistModel updatedPlaylist) async {
    try {
      final playlistIndex = _playlists.indexWhere(
        (p) => p.id == updatedPlaylist.id,
      );
      if (playlistIndex >= 0) {
        _playlists[playlistIndex] = updatedPlaylist.copyWith(
          updatedAt: DateTime.now(),
        );
        await _savePlaylists();

        // Sync with Supabase
        if (_useSupabase) {
          final supabaseUuid = _playlistUuidMap[updatedPlaylist.id];
          if (supabaseUuid != null) {
            await _supabaseService.updatePlaylist(
              supabaseUuid,
              updatedPlaylist.name,
              updatedPlaylist.description,
            );
          }
        }

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error updating playlist: $e');
      return false;
    }
  }

  // Refresh data from Supabase
  Future<void> refreshFromSupabase() async {
    _isLoading = true;
    notifyListeners();

    await _loadFromSupabase();

    _isLoading = false;
    notifyListeners();
  }
}
