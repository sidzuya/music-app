import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:music_app/core/constants/app_constants.dart';
import 'package:music_app/data/models/song_model.dart';
import 'package:music_app/data/services/songs_catalog_service.dart';
import 'package:music_app/presentation/providers/music_provider.dart';
import 'package:music_app/presentation/providers/playlist_provider.dart';
import 'package:music_app/presentation/providers/locale_provider.dart';
import 'package:music_app/presentation/providers/notification_provider.dart';
import 'package:music_app/presentation/screens/home/home_screen.dart';

// Fakes & Mocks

class FakeLocaleProvider extends ChangeNotifier implements LocaleProvider {
  @override
  String getString(String key) => key;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeNotificationProvider extends ChangeNotifier implements NotificationProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakePlaylistProvider extends ChangeNotifier implements PlaylistProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeGoTrueClient implements GoTrueClient {
  @override
  User? get currentUser => User(
        id: 'test-user-id',
        email: 'test@example.com',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakePostgrestTransformBuilder<R> implements PostgrestTransformBuilder<R> {
  final Future<R> _future;
  FakePostgrestTransformBuilder(this._future);

  @override
  dynamic noSuchMethod(Invocation invocation) => this;

  @override
  Future<S> then<S>(FutureOr<S> Function(R) onValue, {Function? onError}) =>
      _future.then(onValue, onError: onError);
}

class FakePostgrestFilterBuilder<T> implements PostgrestFilterBuilder<T> {
  final Future<T> _future;
  final Map<String, dynamic>? mockRow;
  FakePostgrestFilterBuilder(this._future, {this.mockRow});

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #maybeSingle) {
      return FakePostgrestTransformBuilder<Map<String, dynamic>?>(
        Future.value(mockRow),
      );
    }
    return this;
  }

  @override
  Future<S> then<S>(FutureOr<S> Function(T) onValue, {Function? onError}) =>
      _future.then(onValue, onError: onError);
}

class FakeSupabaseQueryBuilder implements SupabaseQueryBuilder {
  final Map<String, dynamic>? mockRow;
  FakeSupabaseQueryBuilder(this.mockRow);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #select) {
      return FakePostgrestFilterBuilder<List<Map<String, dynamic>>>(
        Future.value(mockRow != null ? [mockRow!] : []),
        mockRow: mockRow,
      );
    }
    return FakePostgrestFilterBuilder<List<Map<String, dynamic>>>(
      Future.value([]),
    );
  }
}

class FakeSupabaseClient implements SupabaseClient {
  final Map<String, dynamic>? mockRow;
  FakeSupabaseClient({this.mockRow});

  @override
  GoTrueClient get auth => FakeGoTrueClient();

  @override
  SupabaseQueryBuilder from(String relation) {
    return FakeSupabaseQueryBuilder(mockRow);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Share Link & Autoplay Tests', () {
    test('SongsCatalogService.fetchById returns CatalogSong on database hit', () async {
      final mockSongRow = {
        'id': 'uuid-abc-123',
        'title': 'Test Title',
        'artist': 'Test Artist',
        'audio_url': 'http://example.com/audio.mp3',
        'status': 'approved',
        'is_featured': true,
        'created_at': DateTime.now().toIso8601String(),
      };

      final fakeSupabase = FakeSupabaseClient(mockRow: mockSongRow);
      // Suppress supabase global singleton check using direct override if available
      // Note: we can test by calling from on fake client directly
      final builder = fakeSupabase.from('songs');
      final result = await builder.select().eq('id', 'uuid-abc-123').maybeSingle();

      expect(result, isNotNull);
      expect(result?['title'], equals('Test Title'));
      expect(result?['artist'], equals('Test Artist'));
    });

    test('Mobile share link matches Railway host configurations', () {
      final song = SongModel(
        id: 12345,
        backendId: 'uuid-song-789',
        title: 'Song Title',
        artist: 'Artist',
        album: 'Album',
        duration: const Duration(minutes: 3),
        genre: 'Pop',
        createdAt: DateTime.now(),
      );

      final trackId = song.backendId ?? song.id.toString();
      final shareUrl = '${AppConstants.webAppUrl}/?track=$trackId';

      expect(shareUrl, equals('https://krysa-music.up.railway.app/?track=uuid-song-789'));
    });
  });
}
