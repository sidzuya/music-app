import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import '../models/song_model.dart';

/// Music catalog service backed by the public Audius API.
///
/// Audius gives us a large remote catalog plus a dedicated stream endpoint,
/// so we no longer need to upload every song manually.
class AudiusMusicService {
  static final AudiusMusicService _instance = AudiusMusicService._internal();

  factory AudiusMusicService() => _instance;

  AudiusMusicService._internal();

  final http.Client _httpClient = http.Client();

  Future<List<SongModel>> getPopularSongs({
    int limit = 30,
    String? genre,
    String time = 'week',
  }) async {
    try {
      return await _fetchTracks(
        path: '/tracks/trending',
        queryParameters: {
          'limit': '$limit',
          'time': time,
          if (genre != null && genre.trim().isNotEmpty)
            'genre': _normalizeGenre(genre),
        },
      );
    } catch (e) {
      debugPrint('AudiusMusicService.getPopularSongs error: $e');
      return [];
    }
  }

  Future<List<SongModel>> getSongsByGenre(
    String genre, {
    int limit = 30,
  }) async {
    return getPopularSongs(limit: limit, genre: genre);
  }

  Future<List<SongModel>> searchSongs(String query, {int limit = 30}) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return [];

    try {
      final results = await _fetchTracks(
        path: '/tracks/search',
        queryParameters: {'query': trimmedQuery, 'limit': '$limit'},
      );

      if (results.isNotEmpty) {
        return results;
      }

      return getSongsByGenre(trimmedQuery, limit: limit);
    } catch (e) {
      debugPrint('AudiusMusicService.searchSongs error: $e');
      return [];
    }
  }

  Future<List<SongModel>> _fetchTracks({
    required String path,
    required Map<String, String> queryParameters,
  }) async {
    final uri = Uri.parse('${AppConstants.audiusBaseUrl}$path').replace(
      queryParameters: {
        ...queryParameters,
        'app_name': AppConstants.audiusAppName,
      },
    );

    final response = await _httpClient.get(uri, headers: _headers);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Audius request failed (${response.statusCode}): ${response.body}',
      );
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final rawData = payload['data'];

    if (rawData is! List) {
      return [];
    }

    final seenIds = <int>{};
    final songs = <SongModel>[];

    for (final item in rawData) {
      final track = _asMap(item);
      final song = _mapTrack(track);
      if (song == null || !seenIds.add(song.id ?? -1)) {
        continue;
      }
      songs.add(song);
    }

    return songs;
  }

  SongModel? _mapTrack(Map<String, dynamic> track) {
    final trackId = _asInt(track['track_id']) ?? _asInt(track['id']);
    if (trackId == null) return null;

    final canStream =
        track['is_streamable'] != false &&
        (_asMap(track['access'])['stream'] != false);
    if (!canStream) return null;

    final user = _asMap(track['user']);
    final artwork = _asMap(track['artwork']);
    final albumBacklink = _asMap(track['album_backlink']);

    final title = _asString(track['title']) ?? 'Unknown Track';
    final artist =
        _asString(user['name']) ??
        _asString(user['handle']) ??
        'Unknown Artist';
    final album =
        _asString(albumBacklink['title']) ??
        _asString(albumBacklink['playlist_name']) ??
        'Audius';

    final albumArt =
        _asString(artwork['480x480']) ??
        _asString(artwork['1000x1000']) ??
        _asString(artwork['150x150']);

    final createdAt =
        _asDateTime(track['release_date']) ??
        _asDateTime(track['created_at']) ??
        DateTime.now();

    return SongModel(
      id: trackId,
      title: title,
      artist: artist,
      album: album,
      albumArt: albumArt,
      audioUrl: _buildStreamUrl(trackId),
      duration: Duration(seconds: _asInt(track['duration']) ?? 0),
      genre: _asString(track['genre']) ?? 'Unknown',
      createdAt: createdAt,
    );
  }

  String _buildStreamUrl(int trackId) {
    final appName = Uri.encodeQueryComponent(AppConstants.audiusAppName);
    return '${AppConstants.audiusBaseUrl}/tracks/$trackId/stream?app_name=$appName';
  }

  Map<String, String> get _headers {
    final headers = <String, String>{'Accept': 'application/json'};

    final token = AppConstants.audiusBearerToken.trim();
    if (token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  String _normalizeGenre(String genre) {
    const genreMap = {
      'Hip-Hop': 'Hip-Hop/Rap',
      'Hip Hop': 'Hip-Hop/Rap',
      'R&B': 'R&B/Soul',
    };

    return genreMap[genre] ?? genre;
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  String? _asString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  DateTime? _asDateTime(Object? value) {
    final raw = _asString(value);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }
}
