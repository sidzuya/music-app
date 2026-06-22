import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/song_model.dart';
import '../models/catalog_song_model.dart';
import 'audius_music_service.dart';
import 'mock_music_service.dart';
import 'songs_catalog_service.dart';
import 'supabase_service.dart';

class HybridMusicService {
  static final HybridMusicService _instance = HybridMusicService._internal();

  factory HybridMusicService() => _instance;

  HybridMusicService._internal();

  static const String _itunesSearchUrl = 'https://itunes.apple.com/search';
  static const Duration _cacheTtl = Duration(minutes: 20);

  final AudiusMusicService _audiusService = AudiusMusicService();
  final MockMusicService _fallbackService = MockMusicService();
  final SupabaseService _supabaseService = SupabaseService.instance;
  final http.Client _httpClient = http.Client();
  final Map<String, _CachedSongs> _cache = {};

  Future<List<SongModel>> getPopularSongs({
    int limit = 30,
    String? genre,
    String time = 'week',
  }) async {
    final cacheKey = 'popular:${_normalize(genre ?? 'all')}:$limit:$time';
    final cached = _getCached(cacheKey);
    if (cached != null) {
      return cached.take(limit).toList();
    }

    try {
      final results = await Future.wait([
        _fetchItunesPopularSongs(genre: genre, limit: max(limit, 36)),
        _audiusService.getPopularSongs(
          limit: max(limit, 42),
          genre: genre,
          time: time,
        ),
      ]);

      final merged = _mergeSongBuckets(
        primary: results[0],
        secondary: results[1],
        limit: limit,
      );

      if (merged.isNotEmpty) {
        _setCached(cacheKey, merged);
        return merged;
      }
    } catch (error) {
      debugPrint('HybridMusicService.getPopularSongs error: $error');
    }

    final fallback = await _fallbackService.getPopularSongs(limit: limit);
    _setCached(cacheKey, fallback);
    return fallback;
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

    final cacheKey = 'search:${_normalize(trimmedQuery)}:$limit';
    final cached = _getCached(cacheKey);
    if (cached != null) {
      return cached.take(limit).toList();
    }

    try {
      final results = await Future.wait([
        _searchItunesSongs(trimmedQuery, limit: max(limit, 18)),
        _audiusService.searchSongs(trimmedQuery, limit: max(limit, 18)),
        _supabaseService.searchSongs(trimmedQuery),
        SongsCatalogService.searchApproved(trimmedQuery, limit: max(limit, 18)),
      ]);

      // Catalog (DB) songs come first, then legacy storage matches, then external.
      final catalogRows = results[3] as List<CatalogSong>;
      final catalogSongs = catalogRows
          .map((s) => SongModel(
                id: s.id.hashCode,
                backendId: s.id,
                title: s.title,
                artist: s.artist,
                album: s.album ?? '',
                albumArt: s.coverUrl,
                audioUrl: s.audioUrl,
                duration: s.durationSeconds != null
                    ? Duration(seconds: s.durationSeconds!)
                    : Duration.zero,
                genre: s.genre ?? '',
                createdAt: s.createdAt,
              ))
          .toList();

      final supabaseResults = results[2] as List<dynamic>;
      final seen = <String>{
        for (final s in catalogSongs)
          if (s.audioUrl != null) s.audioUrl!,
      };
      final supabaseSongs = supabaseResults
          .where((s) => !seen.contains(s.audioUrl))
          .map((s) => SongModel(
                id: s.id.hashCode,
                title: s.title,
                artist: s.artist,
                album: 'Supabase',
                albumArt: s.coverUrl,
                audioUrl: s.audioUrl,
                duration: Duration.zero,
                genre: '',
                createdAt: s.uploadedAt,
              ))
          .toList();

      final merged = _mergeSongBuckets(
        primary: results[0] as List<SongModel>,
        secondary: results[1] as List<SongModel>,
        limit: limit,
      );

      final combined =
          [...catalogSongs, ...supabaseSongs, ...merged].take(limit).toList();

      if (combined.isNotEmpty) {
        _setCached(cacheKey, combined);
        return combined;
      }
    } catch (error) {
      debugPrint('HybridMusicService.searchSongs error: $error');
    }

    final fallback = await _fallbackService.searchSongs(trimmedQuery);
    _setCached(cacheKey, fallback);
    return fallback.take(limit).toList();
  }

  Future<List<SongModel>> _fetchItunesPopularSongs({
    String? genre,
    required int limit,
  }) async {
    final seedQueries = _seedQueriesForGenre(genre);
    if (seedQueries.isEmpty) return [];

    final perQueryLimit = min(10, max(6, (limit / seedQueries.length).ceil()));
    final futures = seedQueries
        .map((query) => _searchItunesSongs(query, limit: perQueryLimit))
        .toList();
    final results = await Future.wait(futures);

    return _flattenUnique(results, limit: limit);
  }

  Future<List<SongModel>> _searchItunesSongs(
    String query, {
    int limit = 12,
  }) async {
    final cacheKey = 'itunes:${_normalize(query)}:$limit';
    final cached = _getCached(cacheKey);
    if (cached != null) {
      return cached.take(limit).toList();
    }

    final uri = Uri.parse(_itunesSearchUrl).replace(
      queryParameters: {
        'term': query,
        'media': 'music',
        'entity': 'song',
        'country': 'US',
        'lang': 'en_us',
        'limit': '${min(max(limit, 1), 25)}',
      },
    );

    final response = await _httpClient.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'iTunes Search request failed (${response.statusCode}): ${response.body}',
      );
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final rawResults = payload['results'];
    if (rawResults is! List) {
      return [];
    }

    final songs = <SongModel>[];
    final seen = <String>{};

    for (final item in rawResults) {
      final track = _asMap(item);
      final song = _mapItunesTrack(track);
      if (song == null) continue;

      final key = _songKey(song);
      if (seen.add(key)) {
        songs.add(song);
      }
      if (songs.length >= limit) break;
    }

    _setCached(cacheKey, songs);
    return songs;
  }

  SongModel? _mapItunesTrack(Map<String, dynamic> track) {
    final previewUrl = _asString(track['previewUrl']);
    if (previewUrl == null || previewUrl.isEmpty) {
      return null;
    }

    final title = _asString(track['trackName']);
    final artist = _asString(track['artistName']);
    if (title == null || artist == null) {
      return null;
    }

    final album = _asString(track['collectionName']) ?? 'Apple Music Preview';
    final genre = _asString(track['primaryGenreName']) ?? 'Pop';
    final durationMs = _asInt(track['trackTimeMillis']) ?? 30000;

    return SongModel(
      id: _asInt(track['trackId']),
      title: title,
      artist: artist,
      album: album,
      albumArt: _upgradeArtworkUrl(_asString(track['artworkUrl100'])),
      audioUrl: previewUrl,
      duration: Duration(milliseconds: max(durationMs, 30000)),
      genre: genre,
      createdAt:
          DateTime.tryParse(_asString(track['releaseDate']) ?? '') ??
          DateTime.now(),
    );
  }

  List<SongModel> _mergeSongBuckets({
    required List<SongModel> primary,
    required List<SongModel> secondary,
    required int limit,
  }) {
    final merged = <SongModel>[];
    final seen = <String>{};
    var primaryIndex = 0;
    var secondaryIndex = 0;

    void takePrimary(int count) {
      var picked = 0;
      while (primaryIndex < primary.length &&
          picked < count &&
          merged.length < limit) {
        final song = primary[primaryIndex++];
        final key = _songKey(song);
        if (seen.add(key)) {
          merged.add(song);
          picked++;
        }
      }
    }

    void takeSecondary(int count) {
      var picked = 0;
      while (secondaryIndex < secondary.length &&
          picked < count &&
          merged.length < limit) {
        final song = secondary[secondaryIndex++];
        final key = _songKey(song);
        if (seen.add(key)) {
          merged.add(song);
          picked++;
        }
      }
    }

    while (merged.length < limit &&
        (primaryIndex < primary.length || secondaryIndex < secondary.length)) {
      final before = merged.length;
      takePrimary(2);
      takeSecondary(1);

      if (merged.length == before) break;
    }

    if (merged.length < limit) {
      for (final song in [...primary, ...secondary]) {
        final key = _songKey(song);
        if (seen.add(key)) {
          merged.add(song);
        }
        if (merged.length >= limit) break;
      }
    }

    return merged.take(limit).toList();
  }

  List<SongModel> _flattenUnique(
    List<List<SongModel>> buckets, {
    required int limit,
  }) {
    final songs = <SongModel>[];
    final seen = <String>{};

    for (final bucket in buckets) {
      for (final song in bucket) {
        final key = _songKey(song);
        if (seen.add(key)) {
          songs.add(song);
        }
        if (songs.length >= limit) {
          return songs;
        }
      }
    }

    return songs;
  }

  List<String> _seedQueriesForGenre(String? genre) {
    final normalizedGenre = _normalize(genre ?? '');
    final List<String> seeds;

    if (_matchesGenre(normalizedGenre, const [
      'rock',
      'hard rock',
      'alternative rock',
      'metal',
      'punk',
    ])) {
      seeds = [
        'Linkin Park',
        'Queen',
        'Metallica',
        'AC/DC',
        'Arctic Monkeys',
        'Foo Fighters',
      ];
    } else if (_matchesGenre(normalizedGenre, const [
      'hip-hop',
      'hip hop',
      'rap',
      'hip-hop/rap',
    ])) {
      seeds = [
        'Drake',
        'Kendrick Lamar',
        'Travis Scott',
        'Eminem',
        'Future',
        'J. Cole',
      ];
    } else if (_matchesGenre(normalizedGenre, const [
      'pop',
      'dance pop',
      'pop rock',
      'synth-pop',
    ])) {
      seeds = [
        'Taylor Swift',
        'The Weeknd',
        'Dua Lipa',
        'Billie Eilish',
        'Ariana Grande',
        'Ed Sheeran',
      ];
    } else if (_matchesGenre(normalizedGenre, const [
      'indie',
      'indie pop',
      'alternative',
      'dream pop',
    ])) {
      seeds = [
        'Lana Del Rey',
        'The Neighbourhood',
        'Arctic Monkeys',
        'Billie Eilish',
        'Tame Impala',
        'The 1975',
      ];
    } else if (_matchesGenre(normalizedGenre, const [
      'electronic',
      'edm',
      'dance',
      'house',
    ])) {
      seeds = [
        'Calvin Harris',
        'David Guetta',
        'Skrillex',
        'Avicii',
        'Disclosure',
        'Zedd',
      ];
    } else if (_matchesGenre(normalizedGenre, const [
      'r&b',
      'rnb',
      'soul',
      'r&b/soul',
    ])) {
      seeds = [
        'SZA',
        'The Weeknd',
        'Brent Faiyaz',
        'Frank Ocean',
        'Doja Cat',
        'Rihanna',
      ];
    } else if (_matchesGenre(normalizedGenre, const [
      'k-pop',
      'kpop',
      'korean pop',
      'korean',
      'кейпоп',
      'к-поп',
      'кпоп',
      'корейск',
    ])) {
      seeds = [
        'BTS',
        'BLACKPINK',
        'NewJeans',
        'Stray Kids',
        'TWICE',
        'SEVENTEEN',
        'EXO',
        'aespa',
      ];
    } else if (_matchesGenre(normalizedGenre, const ['workout', 'gym'])) {
      seeds = [
        'Eminem',
        'Linkin Park',
        'Travis Scott',
        'Metallica',
        'Kanye West',
        'AC/DC',
      ];
    } else {
      seeds = [
        'The Weeknd',
        'Taylor Swift',
        'Drake',
        'Billie Eilish',
        'Dua Lipa',
        'Imagine Dragons',
        'Kendrick Lamar',
        'Eminem',
        'Lana Del Rey',
        'Arctic Monkeys',
      ];
    }

    final rotated = _rotatedSeeds(seeds, count: 4);
    if (genre == null || genre.trim().isEmpty) {
      return rotated;
    }

    return ['${genre.trim()} hits', ...rotated].take(4).toList();
  }

  List<String> _rotatedSeeds(List<String> seeds, {required int count}) {
    if (seeds.length <= count) return seeds;

    final dayOffset = DateTime.now().difference(DateTime(2024)).inDays.abs();
    final start = dayOffset % seeds.length;

    return List.generate(
      count,
      (index) => seeds[(start + index) % seeds.length],
    );
  }

  void clearCache() {
    _cache.clear();
  }

  List<SongModel>? _getCached(String key) {
    final cached = _cache[key];
    if (cached == null) return null;
    if (DateTime.now().difference(cached.createdAt) > _cacheTtl) {
      _cache.remove(key);
      return null;
    }
    return List<SongModel>.from(cached.songs);
  }

  void _setCached(String key, List<SongModel> songs) {
    _cache[key] = _CachedSongs(
      songs: List<SongModel>.from(songs),
      createdAt: DateTime.now(),
    );
  }

  String? _upgradeArtworkUrl(String? artworkUrl) {
    if (artworkUrl == null || artworkUrl.isEmpty) return null;
    return artworkUrl.replaceAll('100x100bb', '600x600bb');
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry('$key', item));
    }
    return const {};
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  String? _asString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _songKey(SongModel song) =>
      '${_normalize(song.title)}::${_normalize(song.artist)}';

  String _normalize(String value) => value.trim().toLowerCase();

  bool _matchesGenre(String value, List<String> probes) {
    if (value.isEmpty) return false;
    for (final probe in probes) {
      if (value.contains(probe)) {
        return true;
      }
    }
    return false;
  }
}

class _CachedSongs {
  final List<SongModel> songs;
  final DateTime createdAt;

  const _CachedSongs({required this.songs, required this.createdAt});
}
