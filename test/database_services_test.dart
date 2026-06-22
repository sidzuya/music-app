import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/data/models/song_model.dart';
import 'package:music_app/data/services/supabase_database_service.dart';
import 'package:music_app/data/services/collab_playlist_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakePostgrestTransformBuilder<R> implements PostgrestTransformBuilder<R> {
  final Future<R> _future;

  FakePostgrestTransformBuilder(this._future);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return this;
  }

  @override
  Future<S> then<S>(FutureOr<S> Function(R) onValue, {Function? onError}) => _future.then(onValue, onError: onError);

  @override
  Future<R> catchError(Function onError, {bool Function(Object)? test}) => _future.catchError(onError, test: test);

  @override
  Future<R> timeout(Duration timeLimit, {FutureOr<R> Function()? onTimeout}) => _future.timeout(timeLimit, onTimeout: onTimeout);

  @override
  Stream<R> asStream() => _future.asStream();

  @override
  Future<R> whenComplete(FutureOr<void> Function() action) => _future.whenComplete(action);
}

// Simple fakes to capture insert calls
class FakePostgrestFilterBuilder<T> implements PostgrestFilterBuilder<T> {
  final Map<String, dynamic>? lastInsertPayload;
  final String tableName;
  final Future<T> _future;

  FakePostgrestFilterBuilder(this.tableName, this._future, {this.lastInsertPayload});

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #maybeSingle) {
      if (tableName == 'profiles') {
        return FakePostgrestTransformBuilder<Map<String, dynamic>?>(
          Future.value({'username': 'test_user'}),
        );
      }
      if (tableName == 'playlist_songs') {
        return FakePostgrestTransformBuilder<Map<String, dynamic>?>(
          Future.value({'position': 5}),
        );
      }
      return FakePostgrestTransformBuilder<Map<String, dynamic>?>(Future.value(null));
    }
    return this;
  }

  @override
  Future<S> then<S>(FutureOr<S> Function(T) onValue, {Function? onError}) => _future.then(onValue, onError: onError);

  @override
  Future<T> catchError(Function onError, {bool Function(Object)? test}) => _future.catchError(onError, test: test);

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) => _future.timeout(timeLimit, onTimeout: onTimeout);

  @override
  Stream<T> asStream() => _future.asStream();

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) => _future.whenComplete(action);
}

class FakeSupabaseQueryBuilder implements SupabaseQueryBuilder {
  final String tableName;
  final Function(Map<String, dynamic>) onInsert;

  FakeSupabaseQueryBuilder(this.tableName, this.onInsert);

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> insert(dynamic values, {bool defaultToNull = false}) {
    if (values is Map<String, dynamic>) {
      onInsert(values);
    }
    final List<Map<String, dynamic>> dummyList = [];
    return FakePostgrestFilterBuilder<List<Map<String, dynamic>>>(
      tableName,
      Future.value(dummyList),
      lastInsertPayload: values is Map<String, dynamic> ? values : null,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final List<Map<String, dynamic>> dummyList = [];
    return FakePostgrestFilterBuilder<List<Map<String, dynamic>>>(
      tableName,
      Future.value(dummyList),
    );
  }
}

class FakeGoTrueClient implements GoTrueClient {
  @override
  User? get currentUser => User(
        id: 'user-uuid-123',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSupabaseClient implements SupabaseClient {
  final Map<String, List<Map<String, dynamic>>> insertedRows = {};

  @override
  GoTrueClient get auth => FakeGoTrueClient();

  @override
  SupabaseQueryBuilder from(String relation) {
    return FakeSupabaseQueryBuilder(relation, (payload) {
      insertedRows.putIfAbsent(relation, () => []).add(payload);
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Database Services TDD Tests', () {
    late FakeSupabaseClient fakeClient;
    late SongModel testSong;

    setUp(() {
      fakeClient = FakeSupabaseClient();
      testSong = SongModel(
        id: 1,
        title: 'Apocalypse',
        artist: 'Cigarettes After Sex',
        album: 'Cigarettes After Sex',
        albumArt: 'https://example.com/cover.jpg',
        audioUrl: 'https://example.com/song.mp3',
        duration: const Duration(seconds: 200),
        genre: 'Dream Pop',
        createdAt: DateTime.now(),
      );
    });

    test('SupabaseDatabaseService.addSongToPlaylist should NOT include song_cover_url in the insert payload', () async {
      // 1. Arrange: Initialize SupabaseDatabaseService with our fake client
      final dbService = SupabaseDatabaseService(client: fakeClient);

      // 2. Act: Call addSongToPlaylist
      final result = await dbService.addSongToPlaylist('playlist-uuid-456', testSong);

      // 3. Assert: Verify the payload sent to playlist_songs table
      expect(result, isTrue);
      expect(fakeClient.insertedRows['playlist_songs'], isNotNull);
      expect(fakeClient.insertedRows['playlist_songs']!.length, 1);

      final payload = fakeClient.insertedRows['playlist_songs']!.first;
      expect(payload.containsKey('song_cover_url'), isFalse,
          reason: 'song_cover_url does not exist in Supabase database schema and causes insert failure.');
      expect(payload['song_title'], 'Apocalypse');
    });

    test('CollabPlaylistService.addSongWithCredit should NOT include song_cover_url in the insert payload', () async {
      // 1. Arrange: Initialize CollabPlaylistService with our fake client
      final collabService = CollabPlaylistService(client: fakeClient);

      // 2. Act: Call addSongWithCredit
      final result = await collabService.addSongWithCredit('playlist-uuid-456', testSong);

      // 3. Assert: Verify the payload sent to playlist_songs table
      expect(result, isTrue);
      expect(fakeClient.insertedRows['playlist_songs'], isNotNull);
      expect(fakeClient.insertedRows['playlist_songs']!.length, 1);

      final payload = fakeClient.insertedRows['playlist_songs']!.first;
      expect(payload.containsKey('song_cover_url'), isFalse,
          reason: 'song_cover_url does not exist in Supabase database schema and causes insert failure.');
      expect(payload['song_title'], 'Apocalypse');
    });
  });
}
