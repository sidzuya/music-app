import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:music_app/data/models/playlist_model.dart';
import 'package:music_app/data/models/song_model.dart';
import 'package:music_app/presentation/providers/playlist_provider.dart';
import 'package:music_app/presentation/providers/collab_playlist_provider.dart';
import 'package:music_app/presentation/providers/locale_provider.dart';
import 'package:music_app/presentation/providers/music_provider.dart';
import 'package:music_app/presentation/screens/playlist/playlist_detail_screen.dart';

class FakeCollabPlaylistProvider extends ChangeNotifier implements CollabPlaylistProvider {
  String? lastQueriedPlaylistId;

  @override
  Future<List<Map<String, dynamic>>> getCollaborators(String playlistId) async {
    lastQueriedPlaylistId = playlistId;
    return [
      {'id': 'friend-1', 'username': 'Friend'}
    ];
  }

  @override
  Future<bool> isCollaborator(String playlistId) async {
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakePlaylistProvider extends ChangeNotifier implements PlaylistProvider {
  final Map<int, String> _uuids = {
    12345: 'real-supabase-uuid-999',
  };

  @override
  String? getPlaylistUuid(int playlistId) {
    return _uuids[playlistId];
  }

  @override
  List<SongModel> getPlaylistSongs(int playlistId) {
    return [];
  }

  @override
  Future<void> fetchCollabSongs(String supabaseUuid) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeLocaleProvider extends ChangeNotifier implements LocaleProvider {
  @override
  String getString(String key) {
    if (key == 'songs') return 'songs';
    return key;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeMusicProvider extends ChangeNotifier implements MusicProvider {
  @override
  SongModel? get currentSong => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakePlaylistProvider fakePlaylistProvider;
  late FakeCollabPlaylistProvider fakeCollabPlaylistProvider;
  late FakeLocaleProvider fakeLocaleProvider;
  late FakeMusicProvider fakeMusicProvider;
  late PlaylistModel testPlaylist;

  setUp(() {
    fakePlaylistProvider = FakePlaylistProvider();
    fakeCollabPlaylistProvider = FakeCollabPlaylistProvider();
    fakeLocaleProvider = FakeLocaleProvider();
    fakeMusicProvider = FakeMusicProvider();
    testPlaylist = PlaylistModel(
      id: 12345,
      name: 'Test Playlist',
      description: 'desc',
      userId: 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  });

  Widget createTestWidget(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<PlaylistProvider>.value(value: fakePlaylistProvider),
        ChangeNotifierProvider<CollabPlaylistProvider>.value(value: fakeCollabPlaylistProvider),
        ChangeNotifierProvider<LocaleProvider>.value(value: fakeLocaleProvider),
        ChangeNotifierProvider<MusicProvider>.value(value: fakeMusicProvider),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  testWidgets('PlaylistDetailScreen should query collab info using collabPlaylistId (UUID) when provided', (WidgetTester tester) async {
    // 1. Arrange & Act
    await tester.pumpWidget(
      createTestWidget(
        PlaylistDetailScreen(
          playlist: testPlaylist,
          isCollab: true,
          collabPlaylistId: 'real-supabase-uuid-999',
        ),
      ),
    );

    // Wait for async initialization in initState
    await tester.pumpAndSettle();

    // 2. Assert
    expect(fakeCollabPlaylistProvider.lastQueriedPlaylistId, 'real-supabase-uuid-999',
        reason: 'Should query collaborators using the Supabase UUID string, not the integer ID.');
  });

  testWidgets('PlaylistDetailScreen should query collab info using UUID resolved from local mapping if collabPlaylistId is null', (WidgetTester tester) async {
    // 1. Arrange & Act
    await tester.pumpWidget(
      createTestWidget(
        PlaylistDetailScreen(
          playlist: testPlaylist,
          isCollab: true,
          collabPlaylistId: null,
        ),
      ),
    );

    // Wait for async initialization in initState
    await tester.pumpAndSettle();

    // 2. Assert
    expect(fakeCollabPlaylistProvider.lastQueriedPlaylistId, 'real-supabase-uuid-999',
        reason: 'Should resolve the Supabase UUID string using getPlaylistUuid and query collaborators with it.');
  });
}
