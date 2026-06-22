import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/song_model.dart';

class ListeningAnalyticsService {
  ListeningAnalyticsService._();

  static final ListeningAnalyticsService instance =
      ListeningAnalyticsService._();

  static const String _playHistoryKey = 'ai_play_history';
  static const String _favoriteSongsKey = 'favorite_songs';
  static const int _maxEvents = 200;

  final StreamController<void> _signals = StreamController<void>.broadcast();

  Stream<void> get signals => _signals.stream;

  Future<void> recordPlay(SongModel song, {int durationListened = 0}) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await loadPlayHistory();

    history.insert(0, {
      'song': song.toMap(),
      'played_at': DateTime.now().toIso8601String(),
      'duration_listened': durationListened,
    });

    if (history.length > _maxEvents) {
      history.removeRange(_maxEvents, history.length);
    }

    await prefs.setString(_playHistoryKey, jsonEncode(history));
    _signals.add(null);
  }

  Future<List<Map<String, dynamic>>> loadPlayHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final rawHistory = prefs.getString(_playHistoryKey);
    if (rawHistory == null || rawHistory.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(rawHistory);
    if (decoded is! List) {
      return [];
    }

    return decoded
        .whereType<Map>()
        .map((item) => item.map((key, value) => MapEntry('$key', value)))
        .toList();
  }

  Future<List<SongModel>> loadFavoriteSongs() async {
    final prefs = await SharedPreferences.getInstance();
    final rawFavorites = prefs.getString(_favoriteSongsKey);
    if (rawFavorites == null || rawFavorites.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(rawFavorites);
    if (decoded is! List) {
      return [];
    }

    return decoded
        .whereType<Map>()
        .map(
          (item) => SongModel.fromMap(
            item.map((key, value) => MapEntry('$key', value)),
          ),
        )
        .toList();
  }

  void notifyPreferenceChange() {
    _signals.add(null);
  }
}
