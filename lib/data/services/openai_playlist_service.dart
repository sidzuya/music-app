import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import '../models/ai_playlist_model.dart';
import '../models/song_model.dart';
import 'ai_settings_service.dart';
import 'hybrid_music_service.dart';
import 'mock_music_service.dart';

class OpenAiPlaylistService {
  static const int _maxAttemptsPerModel = 2;

  final http.Client _httpClient;
  final HybridMusicService _musicService;
  final MockMusicService _fallbackService;
  final AiSettingsService _aiSettingsService;

  OpenAiPlaylistService({
    http.Client? httpClient,
    HybridMusicService? musicService,
    MockMusicService? fallbackService,
    AiSettingsService? aiSettingsService,
  }) : _httpClient = httpClient ?? http.Client(),
       _musicService = musicService ?? HybridMusicService(),
       _fallbackService = fallbackService ?? MockMusicService(),
       _aiSettingsService = aiSettingsService ?? AiSettingsService.instance;

  Future<bool> isConfigured() => _aiSettingsService.hasOpenAiApiKey();

  Future<AiGeneratedPlaylist> generatePlaylist({
    required String prompt,
    required List<SongModel> recentSongs,
    required List<SongModel> favoriteSongs,
  }) async {
    final apiKey = await _aiSettingsService.getOpenAiApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Google AI Studio API key is not configured.');
    }

    final tasteSignals = _buildTasteSignals(
      recentSongs: recentSongs,
      favoriteSongs: favoriteSongs,
    );

    final plan = await _createPlan(
      apiKey: apiKey,
      prompt: prompt,
      recentSongs: recentSongs,
      favoriteSongs: favoriteSongs,
      tasteSignals: tasteSignals,
    );

    final songs = await _buildPlaylistSongs(
      prompt: prompt,
      plan: plan,
      recentSongs: recentSongs,
      favoriteSongs: favoriteSongs,
      tasteSignals: tasteSignals,
    );

    return AiGeneratedPlaylist(prompt: prompt, plan: plan, songs: songs);
  }

  Future<AiPlaylistPlan> _createPlan({
    required String apiKey,
    required String prompt,
    required List<SongModel> recentSongs,
    required List<SongModel> favoriteSongs,
    required _TasteSignals tasteSignals,
  }) async {
    final models = <String>[
      AppConstants.googleAiPlaylistModel,
      AppConstants.googleAiFallbackPlaylistModel,
    ].map((model) => model.trim()).where((model) => model.isNotEmpty).toSet();

    _GeminiRequestFailure? lastFailure;

    for (final model in models) {
      for (var attempt = 0; attempt < _maxAttemptsPerModel; attempt++) {
        try {
          return await _createPlanWithModel(
            apiKey: apiKey,
            model: model,
            prompt: prompt,
            recentSongs: recentSongs,
            favoriteSongs: favoriteSongs,
            tasteSignals: tasteSignals,
          );
        } on _GeminiRequestFailure catch (failure) {
          lastFailure = failure;

          if (failure.statusCode == 401 || failure.statusCode == 403) {
            throw Exception(_buildUserFacingFailureMessage(failure));
          }

          final canRetrySameModel =
              failure.isRetriable && attempt < _maxAttemptsPerModel - 1;
          if (canRetrySameModel) {
            await Future.delayed(_retryDelayFor(attempt));
            continue;
          }

          break;
        }
      }
    }

    if (lastFailure != null && lastFailure.isRetriable) {
      return _buildLocalFallbackPlan(
        prompt: prompt,
        tasteSignals: tasteSignals,
      );
    }

    throw Exception(_buildUserFacingFailureMessage(lastFailure));
  }

  Future<AiPlaylistPlan> _createPlanWithModel({
    required String apiKey,
    required String model,
    required String prompt,
    required List<SongModel> recentSongs,
    required List<SongModel> favoriteSongs,
    required _TasteSignals tasteSignals,
  }) async {
    http.Response response;

    try {
      response = await _httpClient.post(
        Uri.parse('${AppConstants.googleAiBaseUrl}/$model:generateContent'),
        headers: {'x-goog-api-key': apiKey, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'systemInstruction': {
            'parts': [
              {
                'text': '''
You convert a user's natural-language playlist request into a structured music search plan for a streaming app powered by the iTunes (Apple Music) catalog.

Global defaults (apply unless the user explicitly says otherwise):
- Build the playlist from globally popular, mainstream, widely-recognized songs and artists (think Billboard / Spotify Global charts level: The Weeknd, Taylor Swift, Drake, Billie Eilish, Lana Del Rey, Adele, Coldplay, Imagine Dragons, etc.).
- ALL search_queries MUST be written in English (transliterate or translate the user's request if needed).
- preferred_artists MUST be real, internationally famous artists whose names are searchable on iTunes/Apple Music in English.
- Do NOT include niche, local-only, royalty-free, or compilation-album tracks. Avoid generic titles like "Грустная музыка", "Ночная музыка", "Sad music #1", "Chillout Mix" — those return library/compilation noise.
- The user's prompt language is NOT a hint about the desired song language. Russian/Kazakh/etc. prompt → still global English-language hits by default.

Language / region overrides:
- Only target Russian-language songs if the user explicitly requests Russian / российские / русские / на русском / СНГ / Russian songs / в основном русские.
- Only target K-pop / Korean / Latin / French / etc. if the user explicitly asks for that language or region.
- When a language/region is explicitly requested, populate preferred_artists with the most popular artists from that scene (e.g. Russian: Земфира, Макс Корж, Скриптонит, Pyrokinesis, Три дня дождя; K-pop: BTS, BLACKPINK, NewJeans, Stray Kids).

Rules:
- Return only valid JSON that matches the schema.
- search_queries should be short, in English, and target real famous artists or canonical track titles whenever possible (e.g. "The Weeknd Save Your Tears", "Lana Del Rey sad songs", "Billie Eilish night"). Prefer artist + mood combinations over abstract phrases.
- preferred_genres should stay broad enough to match real catalogs (Pop, Indie, R&B, Alternative, Hip-Hop, etc.).
- avoid_artists should include artists to exclude.
- strict_mode must be true when the user gives hard constraints like only/exclusively/strictly/только/исключительно/без.
- must_match should contain the genres, artists, categories, or descriptors that results must align with.
- must_not_match should contain the genres, artists, categories, or descriptors that must be excluded.
- target_size must be between 8 and 20.
- If the user says only, exclusively, strictly, исключительно, только, без, or asks to exclude a category, the request overrides the taste profile.
- In strict requests, do not include unrelated genres or artists outside the requested category.
- Only blend the user's taste when it does not conflict with the explicit request.
''',
              },
            ],
          },
          'contents': [
            {
              'role': 'user',
              'parts': [
                {
                  'text': jsonEncode({
                    'request': prompt,
                    'taste_context': {
                      'recent_songs': recentSongs
                          .take(8)
                          .map(_songContext)
                          .toList(),
                      'favorite_songs': favoriteSongs
                          .take(8)
                          .map(_songContext)
                          .toList(),
                      'top_genres': tasteSignals.topGenres,
                      'top_artists': tasteSignals.topArtists,
                      'favorite_genres': tasteSignals.favoriteGenres,
                      'favorite_artists': tasteSignals.favoriteArtists,
                    },
                  }),
                },
              ],
            },
          ],
          'generationConfig': {
            'temperature': 0.6,
            'responseMimeType': 'application/json',
            'responseJsonSchema': {
              'type': 'object',
              'additionalProperties': false,
              'properties': {
                'playlist_title': {'type': 'string'},
                'playlist_description': {'type': 'string'},
                'search_queries': {
                  'type': 'array',
                  'items': {'type': 'string'},
                },
                'preferred_genres': {
                  'type': 'array',
                  'items': {'type': 'string'},
                },
                'preferred_artists': {
                  'type': 'array',
                  'items': {'type': 'string'},
                },
                'avoid_artists': {
                  'type': 'array',
                  'items': {'type': 'string'},
                },
                'vibe_keywords': {
                  'type': 'array',
                  'items': {'type': 'string'},
                },
                'must_match': {
                  'type': 'array',
                  'items': {'type': 'string'},
                },
                'must_not_match': {
                  'type': 'array',
                  'items': {'type': 'string'},
                },
                'strict_mode': {'type': 'boolean'},
                'energy': {
                  'type': 'string',
                  'enum': ['low', 'medium', 'high'],
                },
                'target_size': {'type': 'integer', 'minimum': 8, 'maximum': 20},
              },
              'required': [
                'playlist_title',
                'playlist_description',
                'search_queries',
                'preferred_genres',
                'preferred_artists',
                'avoid_artists',
                'vibe_keywords',
                'must_match',
                'must_not_match',
                'strict_mode',
                'energy',
                'target_size',
              ],
            },
          },
        }),
      );
    } on http.ClientException catch (error) {
      throw _GeminiRequestFailure(apiMessage: error.message, isRetriable: true);
    } catch (e) {
      // Covers SocketException on native and network errors on web
      if (e is _GeminiRequestFailure) rethrow;
      throw const _GeminiRequestFailure(
        apiMessage: 'Нет подключения к интернету.',
        isRetriable: true,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _GeminiRequestFailure(
        statusCode: response.statusCode,
        apiMessage: _extractApiErrorMessage(response.body),
        isRetriable: _isRetriableStatus(response.statusCode),
      );
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final rawText = _extractOutputText(payload);
    if (rawText == null || rawText.trim().isEmpty) {
      throw const _GeminiRequestFailure(
        apiMessage: 'Gemini returned an empty playlist plan.',
      );
    }

    return AiPlaylistPlan.fromJson(jsonDecode(rawText) as Map<String, dynamic>);
  }

  AiPlaylistPlan _buildLocalFallbackPlan({
    required String prompt,
    required _TasteSignals tasteSignals,
  }) {
    final normalizedPrompt = _normalize(prompt);
    final searchQueries = <String>[];
    final preferredGenres = <String>[];
    final preferredArtists = <String>[];
    final vibeKeywords = <String>[];
    final avoidArtists = <String>[];
    final mustMatch = <String>[];
    final mustNotMatch = <String>[];

    var energy = 'medium';
    var targetSize = 12;
    var title = 'AI Mix';

    void addUnique(List<String> target, Iterable<String> values) {
      for (final value in values) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) continue;
        final exists = target.any(
          (item) => item.toLowerCase() == trimmed.toLowerCase(),
        );
        if (!exists) {
          target.add(trimmed);
        }
      }
    }

    bool containsAny(List<String> probes) =>
        probes.any((probe) => normalizedPrompt.contains(_normalize(probe)));

    final isStrictRequest = containsAny([
      'только',
      'исключительно',
      'только из',
      'строго',
      'без ',
      'only',
      'exclusively',
      'strictly',
      'nothing but',
      'without ',
    ]);

    if (containsAny([
      'workout',
      'gym',
      'training',
      'run',
      'sport',
      'трениров',
      'зал',
      'кардио',
      'спорт',
      'work out',
    ])) {
      energy = 'high';
      targetSize = 16;
      addUnique(vibeKeywords, ['workout', 'energy', 'power']);
      addUnique(searchQueries, ['workout mix', 'gym motivation']);
      addUnique(mustMatch, ['workout', 'energy']);
      title = 'Workout Mix';
    }

    if (containsAny([
      'hard rock',
      'rock',
      'metal',
      'punk',
      'алт',
      'рок',
      'метал',
      'хард',
      'панк',
    ])) {
      addUnique(preferredGenres, [
        'Hard Rock',
        'Rock',
        'Alternative Rock',
        'Metal',
      ]);
      addUnique(searchQueries, ['hard rock', 'rock workout', 'metal energy']);
      addUnique(vibeKeywords, ['loud', 'aggressive', 'driving']);
      addUnique(mustMatch, ['hard rock', 'rock', 'metal']);
      title = energy == 'high' ? 'Hard Rock Workout' : 'Hard Rock Mix';
    }

    if (containsAny(['sad', 'grust', 'melanch', 'груст', 'печал', 'меланх'])) {
      energy = 'low';
      addUnique(vibeKeywords, ['sad', 'melancholic', 'emotional']);
      addUnique(searchQueries, ['sad songs', 'melancholic mix']);
      addUnique(mustMatch, ['sad', 'melancholic']);
      title = 'Sad Mix';
    }

    if (containsAny(['night', 'ноч', 'late night', 'midnight'])) {
      energy = energy == 'high' ? 'medium' : 'low';
      addUnique(vibeKeywords, ['night', 'late night', 'atmospheric']);
      addUnique(searchQueries, ['night playlist', 'late night vibe']);
      addUnique(mustMatch, ['night', 'late night']);
      title = title == 'Sad Mix' ? 'Sad Night Mix' : 'Night Mix';
    }

    if (containsAny(['lofi', 'lo-fi', 'study', 'focus', 'учеб', 'спокой'])) {
      energy = 'low';
      addUnique(preferredGenres, ['Lo-Fi', 'Chillhop', 'Ambient']);
      addUnique(searchQueries, [
        'lofi study',
        'chill focus',
        'soft instrumental',
      ]);
      addUnique(vibeKeywords, ['focus', 'calm', 'soft']);
      addUnique(mustMatch, ['lo-fi', 'study', 'focus']);
      title = 'Lo-Fi Focus Mix';
    }

    if (containsAny(['indie', 'dream pop', 'dreampop', 'инди'])) {
      addUnique(preferredGenres, ['Indie', 'Dream Pop', 'Indie Pop']);
      addUnique(searchQueries, ['indie dream pop', 'soft indie']);
      addUnique(vibeKeywords, ['dreamy', 'indie']);
      addUnique(mustMatch, ['indie', 'dream pop']);
    }

    if (containsAny([
      'k-pop',
      'kpop',
      'кейпоп',
      'к-поп',
      'кпоп',
      'корейск',
      'bts',
      'blackpink',
    ])) {
      addUnique(preferredGenres, ['K-Pop', 'Korean Pop']);
      addUnique(searchQueries, [
        'k-pop hits',
        'BTS',
        'BLACKPINK',
        'Stray Kids',
      ]);
      addUnique(preferredArtists, [
        'BTS',
        'BLACKPINK',
        'NewJeans',
        'Stray Kids',
        'TWICE',
        'SEVENTEEN',
        'EXO',
      ]);
      addUnique(vibeKeywords, ['k-pop', 'korean pop', 'idol']);
      addUnique(mustMatch, ['k-pop', 'korean pop', 'bts', 'blackpink']);
      addUnique(mustNotMatch, ['indie', 'dream pop', 'alternative']);
      title = 'K-Pop Mix';
    }

    if (!isStrictRequest) {
      addUnique(preferredGenres, tasteSignals.favoriteGenres.take(3));
      addUnique(preferredGenres, tasteSignals.topGenres.take(2));
      addUnique(preferredArtists, tasteSignals.favoriteArtists.take(4));
      addUnique(preferredArtists, tasteSignals.topArtists.take(3));
    }

    addUnique(searchQueries, [prompt]);
    addUnique(searchQueries, preferredGenres.take(3));
    addUnique(searchQueries, preferredArtists.take(2));

    if (preferredGenres.isEmpty) {
      addUnique(preferredGenres, ['Pop', 'Indie']);
    }

    if (vibeKeywords.isEmpty) {
      addUnique(vibeKeywords, ['personalized', 'favorite', 'mix']);
    }

    final description = switch (energy) {
      'high' =>
        'Собрали бодрый микс из твоего запроса, лайков и истории прослушиваний. Gemini был занят, поэтому плейлист собран в резервном режиме.',
      'low' =>
        'Собрали спокойный атмосферный микс из твоего запроса и музыкального вкуса. Gemini был занят, поэтому плейлист собран в резервном режиме.',
      _ =>
        'Собрали персональный микс из твоего запроса и вкуса. Gemini был занят, поэтому плейлист собран в резервном режиме.',
    };

    return AiPlaylistPlan(
      playlistTitle: title,
      playlistDescription: description,
      searchQueries: searchQueries.take(6).toList(),
      preferredGenres: preferredGenres.take(5).toList(),
      preferredArtists: preferredArtists.take(5).toList(),
      avoidArtists: avoidArtists,
      vibeKeywords: vibeKeywords.take(6).toList(),
      mustMatch: mustMatch.take(8).toList(),
      mustNotMatch: mustNotMatch.take(8).toList(),
      strictMode: isStrictRequest,
      energy: energy,
      targetSize: targetSize,
    );
  }

  Future<List<SongModel>> _buildPlaylistSongs({
    required String prompt,
    required AiPlaylistPlan plan,
    required List<SongModel> recentSongs,
    required List<SongModel> favoriteSongs,
    required _TasteSignals tasteSignals,
  }) async {
    final constraints = _buildRequestConstraints(prompt: prompt, plan: plan);
    final futures = <Future<List<SongModel>>>[
      _musicService.getPopularSongs(
        limit: 24,
        genre: constraints.primaryGenreQuery,
      ),
    ];

    for (final query in plan.searchQueries.take(5)) {
      futures.add(_musicService.searchSongs(query, limit: 18));
    }

    for (final genre in plan.preferredGenres.take(4)) {
      futures.add(_musicService.getSongsByGenre(genre, limit: 18));
    }

    for (final artist in plan.preferredArtists.take(4)) {
      futures.add(_musicService.searchSongs(artist, limit: 18));
    }

    for (final artist in constraints.bootstrapArtists.take(4)) {
      futures.add(_musicService.searchSongs(artist, limit: 18));
    }

    if (!constraints.strictMode) {
      for (final artist in tasteSignals.topArtists.take(3)) {
        futures.add(_musicService.searchSongs(artist, limit: 18));
      }

      for (final genre in tasteSignals.topGenres.take(3)) {
        futures.add(_musicService.getSongsByGenre(genre, limit: 18));
      }
    }

    final results = await Future.wait(futures);
    final candidates = <SongModel>[];
    final seen = <String>{};

    for (final bucket in results) {
      for (final song in bucket) {
        final key = _songKey(song);
        if (seen.add(key)) {
          candidates.add(song);
        }
      }
    }

    if (candidates.isEmpty) {
      return _fallbackService.getRecommendations(
        limit: math.min(plan.targetSize, 12),
      );
    }

    final filteredCandidates = constraints.hasHardFilter
        ? candidates
              .where(
                (song) =>
                    !_containsAny(song.artist, plan.avoidArtists) &&
                    !_matchesExcludedConstraints(song, constraints) &&
                    _matchesStrictConstraints(song, constraints),
              )
              .toList()
        : candidates
              .where(
                (song) =>
                    !_containsAny(song.artist, plan.avoidArtists) &&
                    !_matchesExcludedConstraints(song, constraints),
              )
              .toList();

    final effectiveCandidates = filteredCandidates;

    final recentKeys = recentSongs.map(_songKey).toSet();
    final favoriteKeys = favoriteSongs.map(_songKey).toSet();
    final ranked = [...effectiveCandidates];

    ranked.sort((a, b) {
      final scoreA = _scoreSong(
        a,
        plan: plan,
        constraints: constraints,
        recentKeys: recentKeys,
        favoriteKeys: favoriteKeys,
        tasteSignals: tasteSignals,
      );
      final scoreB = _scoreSong(
        b,
        plan: plan,
        constraints: constraints,
        recentKeys: recentKeys,
        favoriteKeys: favoriteKeys,
        tasteSignals: tasteSignals,
      );
      return scoreB.compareTo(scoreA);
    });

    final songs = <SongModel>[];
    final artistUsage = <String, int>{};
    final albumUsage = <String, int>{};
    final coverUsage = <String, int>{};
    final preferredArtists = {
      ...plan.preferredArtists.map(_normalize),
      ...tasteSignals.favoriteArtists.map(_normalize),
      ...tasteSignals.topArtists.take(2).map(_normalize),
    };

    for (final song in ranked) {
      if (_containsAny(song.artist, plan.avoidArtists)) continue;
      if (_matchesExcludedConstraints(song, constraints)) continue;
      if (!constraints.allowCyrillic && _hasCyrillic('${song.title} ${song.artist}')) {
        continue;
      }

      final artistKey = _normalize(song.artist);
      final albumKey = _normalize(song.album);
      final coverKey = song.albumArt ?? '';
      final maxPerArtist = preferredArtists.contains(artistKey) ? 2 : 1;
      if ((artistUsage[artistKey] ?? 0) >= maxPerArtist) {
        continue;
      }
      if (albumKey.isNotEmpty && (albumUsage[albumKey] ?? 0) >= 1) {
        continue;
      }
      if (coverKey.isNotEmpty && (coverUsage[coverKey] ?? 0) >= 1) {
        continue;
      }

      songs.add(song);
      artistUsage[artistKey] = (artistUsage[artistKey] ?? 0) + 1;
      if (albumKey.isNotEmpty) {
        albumUsage[albumKey] = (albumUsage[albumKey] ?? 0) + 1;
      }
      if (coverKey.isNotEmpty) {
        coverUsage[coverKey] = (coverUsage[coverKey] ?? 0) + 1;
      }

      if (songs.length >= plan.targetSize) break;
    }

    if (songs.length >= 8) {
      return songs;
    }

    final fallback = await _fallbackService.getRecommendations(
      limit: plan.targetSize,
    );
    for (final song in fallback) {
      final key = _songKey(song);
      if (seen.add(key)) {
        if (constraints.hasHardFilter &&
            !_matchesStrictConstraints(song, constraints)) {
          continue;
        }
        if (_matchesExcludedConstraints(song, constraints)) {
          continue;
        }
        final artistKey = _normalize(song.artist);
        final maxPerArtist = preferredArtists.contains(artistKey) ? 2 : 1;
        if ((artistUsage[artistKey] ?? 0) >= maxPerArtist) {
          continue;
        }

        songs.add(song);
        artistUsage[artistKey] = (artistUsage[artistKey] ?? 0) + 1;
      }
      if (songs.length >= plan.targetSize) break;
    }

    return songs;
  }

  double _scoreSong(
    SongModel song, {
    required AiPlaylistPlan plan,
    required _RequestConstraints constraints,
    required Set<String> recentKeys,
    required Set<String> favoriteKeys,
    required _TasteSignals tasteSignals,
  }) {
    final searchable = [
      song.title,
      song.artist,
      song.album,
      song.genre,
    ].join(' ').toLowerCase();

    double score = 0;
    final genreKey = _normalize(song.genre);
    final artistKey = _normalize(song.artist);

    if (_containsAny(song.genre, plan.preferredGenres)) score += 6;
    if (_containsAny(song.artist, plan.preferredArtists)) score += 9;
    if (_containsAny(searchable, plan.searchQueries)) score += 4;
    if (_containsAny(searchable, plan.vibeKeywords)) score += 3;
    if (_containsAny(searchable, plan.mustMatch)) score += 5;
    if (_containsAny(searchable, plan.mustNotMatch)) score -= 25;
    if (_containsAny(song.artist, plan.avoidArtists)) score -= 20;
    if (constraints.strictMode) {
      if (_matchesStrictGenre(song, constraints)) score += 10;
      if (_containsAny(song.artist, constraints.requiredArtistProbes)) {
        score += 12;
      }
      score += (tasteSignals.genreAffinity[genreKey] ?? 0) * 1.3;
      score += (tasteSignals.artistAffinity[artistKey] ?? 0) * 1.2;
    } else {
      score += (tasteSignals.genreAffinity[genreKey] ?? 0) * 4.8;
      score += (tasteSignals.artistAffinity[artistKey] ?? 0) * 6.2;
    }
    score += _catalogSourceBoost(song);

    final key = _songKey(song);
    if (recentKeys.contains(key)) score += 1.2;
    if (favoriteKeys.contains(key)) score += 4.0;

    switch (plan.energy) {
      case 'low':
        if (song.duration.inSeconds >= 180) score += 0.8;
        break;
      case 'high':
        if (song.duration.inSeconds <= 240) score += 0.8;
        break;
      default:
        score += 0.2;
    }

    return score;
  }

  double _catalogSourceBoost(SongModel song) {
    final audioUrl = song.audioUrl?.toLowerCase() ?? '';

    if (audioUrl.contains('itunes.apple.com') ||
        audioUrl.contains('audio-ssl.itunes.apple.com') ||
        audioUrl.contains('mzstatic.com')) {
      return 4.5;
    }

    if (audioUrl.contains('api.audius.co')) {
      return 1.0;
    }

    return 1.8;
  }

  _TasteSignals _buildTasteSignals({
    required List<SongModel> recentSongs,
    required List<SongModel> favoriteSongs,
  }) {
    final genreAffinity = <String, double>{};
    final artistAffinity = <String, double>{};
    final topGenres = <String>[];
    final topArtists = <String>[];
    final favoriteGenres = <String>[];
    final favoriteArtists = <String>[];

    void addWeight(
      SongModel song, {
      required double artistWeight,
      required double genreWeight,
    }) {
      final genreKey = _normalize(song.genre);
      final artistKey = _normalize(song.artist);

      if (genreKey.isNotEmpty) {
        genreAffinity[genreKey] = (genreAffinity[genreKey] ?? 0) + genreWeight;
      }
      if (artistKey.isNotEmpty) {
        artistAffinity[artistKey] =
            (artistAffinity[artistKey] ?? 0) + artistWeight;
      }
    }

    for (var index = 0; index < favoriteSongs.length; index++) {
      final song = favoriteSongs[index];
      final weightBoost = math.max(1.0, 5.0 - index * 0.4);
      addWeight(
        song,
        artistWeight: 2.6 * weightBoost,
        genreWeight: 2.0 * weightBoost,
      );
      if (!favoriteGenres.contains(song.genre) && song.genre.isNotEmpty) {
        favoriteGenres.add(song.genre);
      }
      if (!favoriteArtists.contains(song.artist) && song.artist.isNotEmpty) {
        favoriteArtists.add(song.artist);
      }
    }

    for (var index = 0; index < recentSongs.length; index++) {
      final song = recentSongs[index];
      final weightBoost = math.max(1.0, 4.0 - index * 0.3);
      addWeight(
        song,
        artistWeight: 1.8 * weightBoost,
        genreWeight: 1.5 * weightBoost,
      );
    }

    final sortedGenres = genreAffinity.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedArtists = artistAffinity.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final genre in sortedGenres.take(5)) {
      topGenres.add(genre.key);
    }
    for (final artist in sortedArtists.take(5)) {
      topArtists.add(artist.key);
    }

    return _TasteSignals(
      genreAffinity: genreAffinity,
      artistAffinity: artistAffinity,
      topGenres: topGenres,
      topArtists: topArtists,
      favoriteGenres: favoriteGenres.take(5).toList(),
      favoriteArtists: favoriteArtists.take(5).toList(),
    );
  }

  String? _extractOutputText(Map<String, dynamic> payload) {
    final candidates = payload['candidates'];
    if (candidates is! List) return null;

    for (final candidate in candidates) {
      if (candidate is! Map) continue;
      final content = candidate['content'];
      if (content is! Map) continue;
      final parts = content['parts'];
      if (parts is! List) continue;

      for (final part in parts) {
        if (part is! Map) continue;
        final text = part['text'];
        if (text is String && text.trim().isNotEmpty) {
          return text;
        }
      }
    }

    return null;
  }

  String _extractApiErrorMessage(String responseBody) {
    try {
      final payload = jsonDecode(responseBody);
      if (payload is Map<String, dynamic>) {
        final error = payload['error'];
        if (error is Map<String, dynamic>) {
          final message = error['message'];
          if (message is String && message.trim().isNotEmpty) {
            return message.trim();
          }
        }
      }
    } catch (_) {
      // Fall back to the raw body below.
    }

    return responseBody.trim();
  }

  bool _isRetriableStatus(int statusCode) =>
      statusCode == 429 ||
      statusCode == 500 ||
      statusCode == 502 ||
      statusCode == 503 ||
      statusCode == 504;

  Duration _retryDelayFor(int attempt) =>
      Duration(milliseconds: 700 * (attempt + 1));

  String _buildUserFacingFailureMessage(_GeminiRequestFailure? failure) {
    if (failure == null) {
      return 'Не удалось создать AI-плейлист. Попробуй ещё раз.';
    }

    switch (failure.statusCode) {
      case 401:
      case 403:
        return 'Google AI отклонил ключ. Проверь, что Gemini API key активен и у него есть доступ к Gemini API.';
      case 429:
        return 'Для этого Gemini key временно исчерпан лимит запросов. Подожди немного и попробуй снова.';
      case 503:
        return 'Google AI сейчас перегружен. Я попробовал повторить запрос и переключить модель, но сервис всё ещё занят. Попробуй ещё раз через 10-20 секунд.';
      default:
        final message = failure.apiMessage.trim();
        if (message.isNotEmpty) {
          return 'Не удалось создать AI-плейлист: $message';
        }
        return 'Не удалось создать AI-плейлист. Попробуй ещё раз.';
    }
  }

  Map<String, String> _songContext(SongModel song) {
    return {
      'title': song.title,
      'artist': song.artist,
      'album': song.album,
      'genre': song.genre,
    };
  }

  _RequestConstraints _buildRequestConstraints({
    required String prompt,
    required AiPlaylistPlan plan,
  }) {
    final normalizedPrompt = _normalize(prompt);
    final strictMode =
        plan.strictMode ||
        [
          'только',
          'исключительно',
          'строго',
          'без ',
          'only',
          'exclusively',
          'strictly',
          'nothing but',
          'without ',
        ].any(normalizedPrompt.contains);

    final requiredGenreProbes = <String>[...plan.preferredGenres];
    final requiredArtistProbes = <String>[];
    final requiredKeywordProbes = <String>[...plan.mustMatch];
    final excludedKeywordProbes = <String>[...plan.mustNotMatch];
    final bootstrapArtists = <String>[];
    String? primaryGenreQuery;

    final allowCyrillic = [
      'русск',
      'российск',
      'россии',
      'на русском',
      'снг',
      'rus ',
      'russian',
      'cyrillic',
      'кирилл',
    ].any(normalizedPrompt.contains);

    final isKpopRequest =
        normalizedPrompt.contains('k-pop') ||
        normalizedPrompt.contains('kpop') ||
        normalizedPrompt.contains('кейпоп') ||
        normalizedPrompt.contains('к-поп') ||
        normalizedPrompt.contains('кпоп') ||
        normalizedPrompt.contains('корейск') ||
        plan.preferredGenres.any(
          (genre) => _containsAny(genre, ['k-pop', 'kpop', 'korean pop']),
        ) ||
        plan.searchQueries.any(
          (query) =>
              _containsAny(query, ['k-pop', 'kpop', 'korean pop', 'bts']),
        );

    if (!strictMode) {
      requiredArtistProbes.addAll(plan.preferredArtists);
    } else {
      for (final artist in plan.preferredArtists) {
        if (_containsAny(prompt, [artist])) {
          requiredArtistProbes.add(artist);
        }
      }
    }

    if (isKpopRequest) {
      primaryGenreQuery = 'K-Pop';
      requiredGenreProbes.addAll(['K-Pop', 'Korean Pop', 'KPop']);
      requiredKeywordProbes.addAll(['k-pop', 'kpop', 'korean pop']);
      bootstrapArtists.addAll([
        'BTS',
        'BLACKPINK',
        'NewJeans',
        'Stray Kids',
        'TWICE',
        'SEVENTEEN',
        'EXO',
        'aespa',
      ]);
      requiredArtistProbes.addAll(bootstrapArtists);
    }

    _appendPromptExclusions(normalizedPrompt, excludedKeywordProbes);

    return _RequestConstraints(
      strictMode: strictMode,
      primaryGenreQuery: primaryGenreQuery,
      requiredGenreProbes: _uniqueStrings(requiredGenreProbes),
      requiredArtistProbes: _uniqueStrings(requiredArtistProbes),
      requiredKeywordProbes: _uniqueStrings(requiredKeywordProbes),
      excludedKeywordProbes: _uniqueStrings(excludedKeywordProbes),
      bootstrapArtists: _uniqueStrings(bootstrapArtists),
      allowCyrillic: allowCyrillic,
    );
  }

  bool _matchesStrictConstraints(
    SongModel song,
    _RequestConstraints constraints,
  ) {
    if (!constraints.hasHardFilter) return true;

    final searchable = [
      song.title,
      song.artist,
      song.album,
      song.genre,
    ].join(' ').toLowerCase();

    final matchesGenre = _matchesStrictGenre(song, constraints);
    final matchesArtist = _containsAny(
      song.artist,
      constraints.requiredArtistProbes,
    );
    final matchesKeyword = _containsAny(
      searchable,
      constraints.requiredKeywordProbes,
    );

    return matchesGenre || matchesArtist || matchesKeyword;
  }

  bool _matchesStrictGenre(SongModel song, _RequestConstraints constraints) {
    if (constraints.requiredGenreProbes.isEmpty) return false;
    return _containsAny(song.genre, constraints.requiredGenreProbes);
  }

  bool _matchesExcludedConstraints(
    SongModel song,
    _RequestConstraints constraints,
  ) {
    if (constraints.excludedKeywordProbes.isEmpty) return false;

    final searchable = [
      song.title,
      song.artist,
      song.album,
      song.genre,
    ].join(' ').toLowerCase();

    return _containsAny(searchable, constraints.excludedKeywordProbes);
  }

  void _appendPromptExclusions(String normalizedPrompt, List<String> target) {
    const exclusions = {
      'зарубеж': ['western', 'foreign', 'indie', 'alternative'],
      'foreign': ['foreign', 'western'],
      'western': ['western', 'foreign'],
      'без рэп': ['rap', 'hip-hop', 'рэп'],
      'without rap': ['rap', 'hip-hop'],
      'без поп': ['pop'],
      'without pop': ['pop'],
      'без рока': ['rock'],
      'without rock': ['rock'],
    };

    exclusions.forEach((probe, values) {
      if (normalizedPrompt.contains(probe)) {
        target.addAll(values);
      }
    });
  }

  List<String> _uniqueStrings(Iterable<String> items) {
    final values = <String>[];
    for (final item in items) {
      final trimmed = item.trim();
      if (trimmed.isEmpty) continue;
      if (!values.any((value) => _normalize(value) == _normalize(trimmed))) {
        values.add(trimmed);
      }
    }
    return values;
  }

  bool _containsAny(String value, List<String> probes) {
    final normalizedValue = value.toLowerCase();
    for (final probe in probes) {
      final normalizedProbe = probe.toLowerCase().trim();
      if (normalizedProbe.isEmpty) continue;
      if (normalizedValue.contains(normalizedProbe)) {
        return true;
      }
    }
    return false;
  }

  String _songKey(SongModel song) {
    if (song.id != null) return 'id:${song.id}';
    return '${_normalize(song.title)}::${_normalize(song.artist)}';
  }

  String _normalize(String value) => value.trim().toLowerCase();

  static final RegExp _cyrillicRegex = RegExp(r'[\u0400-\u04FF]');

  bool _hasCyrillic(String value) => _cyrillicRegex.hasMatch(value);
}

class _RequestConstraints {
  final bool strictMode;
  final String? primaryGenreQuery;
  final List<String> requiredGenreProbes;
  final List<String> requiredArtistProbes;
  final List<String> requiredKeywordProbes;
  final List<String> excludedKeywordProbes;
  final List<String> bootstrapArtists;
  final bool allowCyrillic;

  const _RequestConstraints({
    required this.strictMode,
    required this.primaryGenreQuery,
    required this.requiredGenreProbes,
    required this.requiredArtistProbes,
    required this.requiredKeywordProbes,
    required this.excludedKeywordProbes,
    required this.bootstrapArtists,
    required this.allowCyrillic,
  });

  bool get hasHardFilter =>
      strictMode &&
      (requiredGenreProbes.isNotEmpty ||
          requiredArtistProbes.isNotEmpty ||
          requiredKeywordProbes.isNotEmpty ||
          excludedKeywordProbes.isNotEmpty);
}

class _GeminiRequestFailure implements Exception {
  final int? statusCode;
  final String apiMessage;
  final bool isRetriable;

  const _GeminiRequestFailure({
    this.statusCode,
    required this.apiMessage,
    this.isRetriable = false,
  });
}

class _TasteSignals {
  final Map<String, double> genreAffinity;
  final Map<String, double> artistAffinity;
  final List<String> topGenres;
  final List<String> topArtists;
  final List<String> favoriteGenres;
  final List<String> favoriteArtists;

  const _TasteSignals({
    required this.genreAffinity,
    required this.artistAffinity,
    required this.topGenres,
    required this.topArtists,
    required this.favoriteGenres,
    required this.favoriteArtists,
  });
}
