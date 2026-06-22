import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../data/models/recommendation_mix_model.dart';
import '../../data/models/song_model.dart';
import '../../data/services/hybrid_music_service.dart';
import '../../data/services/listening_analytics_service.dart';
import '../../data/services/mock_music_service.dart';

class RecommendationProvider with ChangeNotifier {
  final HybridMusicService _musicService = HybridMusicService();
  final MockMusicService _fallbackService = MockMusicService();
  final ListeningAnalyticsService _analyticsService =
      ListeningAnalyticsService.instance;

  final List<RecommendationMixModel> _dailyMixes = [];

  StreamSubscription<void>? _signalsSubscription;
  bool _isLoading = false;
  bool _isInitialized = false;
  DateTime? _lastUpdated;

  List<RecommendationMixModel> get dailyMixes => List.unmodifiable(_dailyMixes);
  bool get isLoading => _isLoading;
  bool get hasMixes => _dailyMixes.isNotEmpty;

  Future<void> initialize() async {
    if (_isInitialized) return;

    _isInitialized = true;
    _signalsSubscription = _analyticsService.signals.listen((_) {
      refreshRecommendations();
    });

    await refreshRecommendations(force: true);
  }

  Future<void> refreshRecommendations({bool force = false}) async {
    if (_isLoading) return;
    if (!force &&
        _lastUpdated != null &&
        DateTime.now().difference(_lastUpdated!) <
            const Duration(seconds: 15)) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final history = await _analyticsService.loadPlayHistory();
      final favorites = await _analyticsService.loadFavoriteSongs();
      final profile = _buildTasteProfile(history, favorites);
      final candidates = await _loadCandidatePool(profile);
      final mixes = _generateMixes(profile, candidates, favorites);

      _dailyMixes
        ..clear()
        ..addAll(mixes);
      _lastUpdated = DateTime.now();
    } catch (error) {
      debugPrint('RecommendationProvider.refreshRecommendations error: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<SongModel>> _loadCandidatePool(_TasteProfile profile) async {
    final futures = <Future<List<SongModel>>>[
      _musicService.getPopularSongs(limit: 72),
    ];

    for (final genre in profile.topGenres.take(3)) {
      futures.add(_musicService.getSongsByGenre(genre, limit: 30));
    }

    for (final artist in profile.topArtists.take(3)) {
      futures.add(_musicService.searchSongs(artist, limit: 24));
    }

    final results = await Future.wait(futures);
    final uniqueSongs = <SongModel>[];
    final seenKeys = <String>{};

    for (final bucket in results) {
      for (final song in bucket) {
        final key = _songKey(song);
        if (seenKeys.add(key)) {
          uniqueSongs.add(song);
        }
      }
    }

    if (uniqueSongs.length < 24) {
      final fallbackSongs = await _fallbackService.getPopularSongs(limit: 24);
      for (final song in fallbackSongs) {
        final key = _songKey(song);
        if (seenKeys.add(key)) {
          uniqueSongs.add(song);
        }
      }
    }

    return uniqueSongs;
  }

  List<RecommendationMixModel> _generateMixes(
    _TasteProfile profile,
    List<SongModel> candidates,
    List<SongModel> favorites,
  ) {
    if (candidates.isEmpty &&
        favorites.isEmpty &&
        profile.recentSongs.isEmpty) {
      return [];
    }

    final comfortCandidates = _rankCandidates(
      candidates,
      profile,
      flavor: _MixFlavor.comfort,
    );
    final discoveryCandidates = _rankCandidates(
      candidates,
      profile,
      flavor: _MixFlavor.discovery,
    );
    final replayCandidates = _rankCandidates(
      candidates,
      profile,
      flavor: _MixFlavor.replay,
    );

    final usedSongKeys = <String>{};
    final globalArtistUsage = <String, int>{};
    final priorityArtists = profile.topArtists
        .map(_normalize)
        .where((artist) => artist.isNotEmpty)
        .toSet();

    final mixOneSongs = _composeMixSongs(
      anchors: [...favorites, ...profile.recentSongs],
      rankedCandidates: comfortCandidates,
      length: 12,
      anchorTarget: 2,
      globalSongExclusions: usedSongKeys,
      globalArtistUsage: globalArtistUsage,
      maxPerArtistInMix: 2,
      maxPerArtistAcrossMixes: 2,
      priorityArtists: priorityArtists,
    );
    _registerMixUsage(mixOneSongs, usedSongKeys, globalArtistUsage);

    final mixTwoSongs = _composeMixSongs(
      anchors: [...profile.recentSongs.reversed, ...favorites.reversed],
      rankedCandidates: discoveryCandidates,
      length: 12,
      anchorTarget: 1,
      globalSongExclusions: usedSongKeys,
      globalArtistUsage: globalArtistUsage,
      maxPerArtistInMix: 1,
      maxPerArtistAcrossMixes: 1,
      priorityArtists: const {},
    );
    _registerMixUsage(mixTwoSongs, usedSongKeys, globalArtistUsage);

    final mixThreeSongs = _composeMixSongs(
      anchors: [...favorites.reversed, ...profile.recentSongs.skip(2)],
      rankedCandidates: replayCandidates,
      length: 12,
      anchorTarget: 3,
      globalSongExclusions: usedSongKeys,
      globalArtistUsage: globalArtistUsage,
      maxPerArtistInMix: 2,
      maxPerArtistAcrossMixes: 2,
      priorityArtists: priorityArtists,
    );

    final mixes = <RecommendationMixModel>[
      RecommendationMixModel(
        id: 'daily_mix_1',
        title: 'Микс дня #1',
        subtitle: _buildMixSubtitle(mixOneSongs),
        description: _buildDescription(
          profile,
          fallback:
              'Знакомые вайбы, любимые жанры и более известные артисты под твой вкус.',
        ),
        songs: mixOneSongs,
      ),
      RecommendationMixModel(
        id: 'daily_mix_2',
        title: 'Микс дня #2',
        subtitle: _buildMixSubtitle(mixTwoSongs),
        description:
            'Больше новых треков и меньше повторов артистов, но всё ещё рядом с твоим вкусом.',
        songs: mixTwoSongs,
      ),
      RecommendationMixModel(
        id: 'daily_mix_3',
        title: 'Микс дня #3',
        subtitle: _buildMixSubtitle(mixThreeSongs),
        description:
            'Фокус на любимом, но без копии первых двух миксов: знакомое вперемешку с новыми находками.',
        songs: mixThreeSongs,
      ),
    ];

    return mixes.where((mix) => mix.songs.isNotEmpty).toList();
  }

  List<SongModel> _rankCandidates(
    List<SongModel> candidates,
    _TasteProfile profile, {
    required _MixFlavor flavor,
  }) {
    final ranked = [...candidates];

    ranked.sort((a, b) {
      final scoreA = _scoreSong(a, profile, flavor: flavor);
      final scoreB = _scoreSong(b, profile, flavor: flavor);
      return scoreB.compareTo(scoreA);
    });

    return ranked;
  }

  double _scoreSong(
    SongModel song,
    _TasteProfile profile, {
    required _MixFlavor flavor,
  }) {
    final genreKey = _normalize(song.genre);
    final artistKey = _normalize(song.artist);
    final songKey = _songKey(song);

    final genreAffinity = profile.genreWeights[genreKey] ?? 0;
    final artistAffinity = profile.artistWeights[artistKey] ?? 0;
    final alreadyPlayed = profile.playedSongKeys.contains(songKey);
    final isFavorite = profile.favoriteSongKeys.contains(songKey);
    final hasFreshArtist = !profile.artistWeights.containsKey(artistKey);

    double score = 0;
    score += _durationCompatibility(song.duration, profile) * 2.0;
    score += song.albumArt != null ? 0.4 : 0;
    score += song.audioUrl != null ? 0.8 : 0;
    score += _catalogSourceBoost(song);

    switch (flavor) {
      case _MixFlavor.comfort:
        score += genreAffinity * 3.2;
        score += artistAffinity * 2.6;
        score += hasFreshArtist ? 0.8 : 1.8;
        score += alreadyPlayed ? -8.0 : 2.8;
        score += isFavorite ? 0.8 : 0;
        break;
      case _MixFlavor.discovery:
        score += genreAffinity * 2.4;
        score += artistAffinity * 0.9;
        score += hasFreshArtist ? 6.5 : 0.6;
        score += alreadyPlayed ? -7.5 : 4.2;
        score += isFavorite ? -5.2 : 0;
        break;
      case _MixFlavor.replay:
        score += genreAffinity * 2.8;
        score += artistAffinity * 3.4;
        score += hasFreshArtist ? 0.2 : 2.2;
        score += alreadyPlayed ? -2.4 : 1.4;
        score += isFavorite ? 3.0 : 0;
        break;
    }

    return score;
  }

  double _durationCompatibility(Duration duration, _TasteProfile profile) {
    if (profile.averageDurationSeconds == 0 || duration.inSeconds == 0) {
      return 0;
    }

    final difference = (duration.inSeconds - profile.averageDurationSeconds)
        .abs();
    return max(0, 1 - (difference / 240));
  }

  List<SongModel> _composeMixSongs({
    required List<SongModel> anchors,
    required List<SongModel> rankedCandidates,
    required int length,
    required int anchorTarget,
    required Set<String> globalSongExclusions,
    required Map<String, int> globalArtistUsage,
    required int maxPerArtistInMix,
    required int maxPerArtistAcrossMixes,
    required Set<String> priorityArtists,
  }) {
    final songs = <SongModel>[];
    final seenKeys = <String>{};
    final artistCounts = <String, int>{};

    bool canUseSong(SongModel song, {required bool relaxed}) {
      final key = _songKey(song);
      final artistKey = _normalize(song.artist);
      final mixLimit = relaxed ? maxPerArtistInMix + 1 : maxPerArtistInMix;
      final globalLimit = relaxed
          ? maxPerArtistAcrossMixes + 1
          : maxPerArtistAcrossMixes;
      final adjustedGlobalLimit = priorityArtists.contains(artistKey)
          ? globalLimit + 1
          : globalLimit;

      if ((song.audioUrl ?? '').isEmpty) return false;
      if (seenKeys.contains(key) || globalSongExclusions.contains(key)) {
        return false;
      }
      if ((artistCounts[artistKey] ?? 0) >= mixLimit) {
        return false;
      }
      if ((globalArtistUsage[artistKey] ?? 0) >= adjustedGlobalLimit) {
        return false;
      }

      return true;
    }

    void rememberSong(SongModel song) {
      final key = _songKey(song);
      final artistKey = _normalize(song.artist);
      seenKeys.add(key);
      songs.add(song);
      artistCounts[artistKey] = (artistCounts[artistKey] ?? 0) + 1;
    }

    for (final song in anchors) {
      if (!canUseSong(song, relaxed: false)) continue;
      rememberSong(song);
      if (songs.length >= anchorTarget) break;
    }

    for (final song in rankedCandidates) {
      if (!canUseSong(song, relaxed: false)) continue;
      rememberSong(song);
      if (songs.length >= length) break;
    }

    if (songs.length < length) {
      for (final song in rankedCandidates) {
        if (!canUseSong(song, relaxed: true)) continue;
        rememberSong(song);
        if (songs.length >= length) break;
      }
    }

    return songs.take(length).toList();
  }

  void _registerMixUsage(
    List<SongModel> songs,
    Set<String> usedSongKeys,
    Map<String, int> globalArtistUsage,
  ) {
    for (final song in songs) {
      final key = _songKey(song);
      final artistKey = _normalize(song.artist);
      usedSongKeys.add(key);
      globalArtistUsage[artistKey] = (globalArtistUsage[artistKey] ?? 0) + 1;
    }
  }

  double _catalogSourceBoost(SongModel song) {
    final audioUrl = song.audioUrl?.toLowerCase() ?? '';

    if (audioUrl.contains('itunes.apple.com') ||
        audioUrl.contains('audio-ssl.itunes.apple.com') ||
        audioUrl.contains('mzstatic.com')) {
      return 4.2;
    }

    if (audioUrl.contains('api.audius.co')) {
      return 0.9;
    }

    return 1.8;
  }

  _TasteProfile _buildTasteProfile(
    List<Map<String, dynamic>> history,
    List<SongModel> favorites,
  ) {
    final genreWeights = <String, double>{};
    final genreLabels = <String, String>{};
    final artistWeights = <String, double>{};
    final artistLabels = <String, String>{};
    final playedSongKeys = <String>{};
    final favoriteSongKeys = favorites.map(_songKey).toSet();
    final recentSongs = <SongModel>[];
    final recentSeenKeys = <String>{};

    double weightedDuration = 0;
    double totalWeight = 0;

    for (var index = 0; index < history.length; index++) {
      final entry = history[index];
      final songMap = entry['song'];
      if (songMap is! Map) continue;

      final song = SongModel.fromMap(
        songMap.map((key, value) => MapEntry('$key', value)),
      );
      final weight = max(1, 8 - min(index, 7)).toDouble();

      final genreKey = _normalize(song.genre);
      final artistKey = _normalize(song.artist);
      final key = _songKey(song);

      if (genreKey.isNotEmpty) {
        genreWeights[genreKey] = (genreWeights[genreKey] ?? 0) + weight * 1.4;
        genreLabels[genreKey] = song.genre;
      }

      if (artistKey.isNotEmpty) {
        artistWeights[artistKey] =
            (artistWeights[artistKey] ?? 0) + weight * 1.2;
        artistLabels[artistKey] = song.artist;
      }

      playedSongKeys.add(key);

      if (song.duration.inSeconds > 0) {
        weightedDuration += song.duration.inSeconds * weight;
        totalWeight += weight;
      }

      if (recentSeenKeys.add(key)) {
        recentSongs.add(song);
      }
    }

    for (final song in favorites) {
      final genreKey = _normalize(song.genre);
      final artistKey = _normalize(song.artist);

      if (genreKey.isNotEmpty) {
        genreWeights[genreKey] = (genreWeights[genreKey] ?? 0) + 5;
        genreLabels[genreKey] = song.genre;
      }

      if (artistKey.isNotEmpty) {
        artistWeights[artistKey] = (artistWeights[artistKey] ?? 0) + 4;
        artistLabels[artistKey] = song.artist;
      }
    }

    final topGenres = _topLabels(genreWeights, genreLabels);
    final topArtists = _topLabels(artistWeights, artistLabels);

    return _TasteProfile(
      genreWeights: genreWeights,
      artistWeights: artistWeights,
      topGenres: topGenres,
      topArtists: topArtists,
      averageDurationSeconds: totalWeight == 0
          ? 0
          : (weightedDuration / totalWeight).round(),
      playedSongKeys: playedSongKeys,
      favoriteSongKeys: favoriteSongKeys,
      recentSongs: recentSongs.take(12).toList(),
    );
  }

  List<String> _topLabels(
    Map<String, double> scores,
    Map<String, String> labels,
  ) {
    final entries = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries
        .take(3)
        .map((entry) => labels[entry.key] ?? entry.key)
        .toList();
  }

  String _buildDescription(_TasteProfile profile, {required String fallback}) {
    if (profile.topGenres.isEmpty && profile.topArtists.isEmpty) {
      return fallback;
    }

    final genres = profile.topGenres.take(2).join(', ');
    final artists = profile.topArtists.take(2).join(', ');

    if (genres.isNotEmpty && artists.isNotEmpty) {
      return 'Собрано из твоих любимых жанров: $genres и артистов: $artists.';
    }
    if (genres.isNotEmpty) {
      return 'Собрано из твоих любимых жанров: $genres.';
    }
    return 'Собрано вокруг артистов, которых ты слушаешь чаще всего: $artists.';
  }

  String _buildMixSubtitle(List<SongModel> songs) {
    final artists = <String>[];

    for (final song in songs) {
      if (!artists.contains(song.artist)) {
        artists.add(song.artist);
      }
      if (artists.length == 3) break;
    }

    if (artists.isEmpty) {
      return 'Новые рекомендации под твой вкус';
    }

    final summary = artists.join(', ');
    return artists.length >= 3 ? '$summary и не только' : summary;
  }

  String _songKey(SongModel song) {
    if (song.id != null) return 'id:${song.id}';
    return '${_normalize(song.title)}::${_normalize(song.artist)}';
  }

  String _normalize(String value) => value.trim().toLowerCase();

  @override
  void dispose() {
    _signalsSubscription?.cancel();
    super.dispose();
  }
}

class _TasteProfile {
  final Map<String, double> genreWeights;
  final Map<String, double> artistWeights;
  final List<String> topGenres;
  final List<String> topArtists;
  final int averageDurationSeconds;
  final Set<String> playedSongKeys;
  final Set<String> favoriteSongKeys;
  final List<SongModel> recentSongs;

  const _TasteProfile({
    required this.genreWeights,
    required this.artistWeights,
    required this.topGenres,
    required this.topArtists,
    required this.averageDurationSeconds,
    required this.playedSongKeys,
    required this.favoriteSongKeys,
    required this.recentSongs,
  });
}

enum _MixFlavor { comfort, discovery, replay }
