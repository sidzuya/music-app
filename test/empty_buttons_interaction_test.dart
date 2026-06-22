import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:music_app/data/models/song_model.dart';
import 'package:music_app/data/models/user_model.dart';
import 'package:music_app/data/models/playlist_model.dart';
import 'package:music_app/presentation/providers/music_provider.dart';
import 'package:music_app/presentation/providers/locale_provider.dart';
import 'package:music_app/presentation/providers/auth_provider.dart';
import 'package:music_app/presentation/providers/playlist_provider.dart';
import 'package:music_app/presentation/providers/collab_playlist_provider.dart';
import 'package:music_app/presentation/screens/player/player_screen.dart';
import 'package:music_app/presentation/screens/settings/account_settings_screen.dart';
import 'package:music_app/presentation/screens/artist/artist_profile_screen.dart';
import 'package:music_app/presentation/screens/album/album_detail_screen.dart';
import 'package:music_app/presentation/widgets/song_tile.dart';
import 'package:music_app/presentation/widgets/playlist_selector_dialog.dart';

class FakeMusicProvider extends ChangeNotifier implements MusicProvider {
  SongModel? _currentSong;
  List<SongModel> _playlist = [];
  bool _isPlaying = false;
  int _currentIndex = 0;
  List<SongModel> _recentlyPlayed = [];

  FakeMusicProvider({
    SongModel? currentSong,
    List<SongModel>? playlist,
  })  : _currentSong = currentSong,
        _playlist = playlist ?? [];

  @override
  SongModel? get currentSong => _currentSong;

  @override
  List<SongModel> get playlist => _playlist;

  @override
  int get currentIndex => _currentIndex;

  @override
  bool get isPlaying => _isPlaying;

  @override
  bool get isLoading => false;

  @override
  Duration get duration => const Duration(seconds: 180);

  @override
  Duration get position => const Duration(seconds: 30);

  @override
  bool get isShuffleEnabled => false;

  @override
  RepeatMode get repeatMode => RepeatMode.off;

  @override
  List<SongModel> get recentlyPlayed => _recentlyPlayed;

  @override
  Future<void> playPlaylist(List<SongModel> songs, int startIndex) async {
    _playlist = songs;
    _currentIndex = startIndex;
    _currentSong = songs[startIndex];
    notifyListeners();
  }

  @override
  Future<void> togglePlayPause() async {
    _isPlaying = !_isPlaying;
    notifyListeners();
  }

  @override
  Future<void> toggleShuffle() async {}

  @override
  Future<void> toggleRepeat() async {}

  @override
  Future<void> skipToNext() async {}

  @override
  Future<void> skipToPrevious() async {}

  @override
  Future<void> seekTo(Duration duration) async {}

  @override
  Future<void> toggleFavorite() async {
    if (_currentSong != null) {
      _currentSong = SongModel(
        id: _currentSong!.id,
        title: _currentSong!.title,
        artist: _currentSong!.artist,
        album: _currentSong!.album,
        audioUrl: _currentSong!.audioUrl,
        duration: _currentSong!.duration,
        genre: _currentSong!.genre,
        createdAt: _currentSong!.createdAt,
        isFavorite: !(_currentSong!.isFavorite ?? false),
      );
      notifyListeners();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakePlaylistProvider extends ChangeNotifier implements PlaylistProvider {
  final List<SongModel> _favoriteSongs = [];
  final List<PlaylistModel> _playlists = [];

  @override
  List<SongModel> get favoriteSongs => _favoriteSongs;

  @override
  List<PlaylistModel> get playlists => _playlists;

  @override
  String? getPlaylistUuid(int id) => null;

  @override
  List<SongModel> getPlaylistSongs(int id) => [];

  @override
  bool isFavorite(SongModel song) {
    return _favoriteSongs.any((s) => s.id == song.id);
  }

  @override
  Future<bool> toggleFavorite(SongModel song) async {
    final index = _favoriteSongs.indexWhere((s) => s.id == song.id);
    if (index >= 0) {
      _favoriteSongs.removeAt(index);
      notifyListeners();
      return false;
    } else {
      _favoriteSongs.add(song.copyWith(isFavorite: true));
      notifyListeners();
      return true;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCollabPlaylistProvider extends ChangeNotifier implements CollabPlaylistProvider {
  @override
  List<String> get mySharedPlaylistIds => [];

  @override
  List<Map<String, dynamic>> get myCollabPlaylists => [];

  @override
  Future<bool> addSong(String playlistId, SongModel song) async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeLocaleProvider extends ChangeNotifier implements LocaleProvider {
  @override
  String getString(String key) {
    switch (key) {
      case 'account':
        return 'Аккаунт';
      case 'profile':
        return 'Профиль';
      case 'security':
        return 'Безопасность';
      case 'privacy':
        return 'Конфиденциальность';
      case 'danger_zone':
        return 'Опасная зона';
      case 'active_sessions':
        return 'Активные сеансы';
      case 'active_sessions_desc':
        return 'Просмотр и управление активными сеансами';
      case 'current_session':
        return 'Текущий сеанс';
      case 'terminate':
        return 'Завершить';
      case 'save':
        return 'Сохранить';
      case 'edit':
        return 'Изменить';
      case 'email':
        return 'Email';
      case 'username':
        return 'Имя пользователя';
      case 'added_to_favorites':
        return 'Добавлено в избранное';
      case 'removed_from_favorites':
        return 'Удалено из избранного';
      case 'share':
        return 'Поделиться';
      case 'add_to_playlist':
        return 'Добавить в плейлист';
      case 'go_to_album':
        return 'Перейти к альбому';
      case 'go_to_artist':
        return 'Перейти к исполнителю';
      default:
        return key;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  final UserModel _user = UserModel(
    id: 1,
    email: 'test@example.com',
    username: 'testuser',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  @override
  UserModel? get currentUser => _user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock clipboard
  final List<ClipboardData> clipboardData = [];
  setUp(() {
    clipboardData.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
      if (methodCall.method == 'Clipboard.setData') {
        final text = (methodCall.arguments as Map)['text'] as String?;
        clipboardData.add(ClipboardData(text: text ?? ''));
        return null;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Widget createPlayerScreen(FakeMusicProvider musicProvider, FakePlaylistProvider playlistProvider) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<MusicProvider>.value(value: musicProvider),
        ChangeNotifierProvider<PlaylistProvider>.value(value: playlistProvider),
        ChangeNotifierProvider<CollabPlaylistProvider>.value(value: FakeCollabPlaylistProvider()),
        ChangeNotifierProvider<LocaleProvider>.value(value: FakeLocaleProvider()),
      ],
      child: const MaterialApp(
        home: PlayerScreen(),
      ),
    );
  }

  Widget createSongTileScreen(SongModel song, FakePlaylistProvider playlistProvider) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<MusicProvider>.value(value: FakeMusicProvider(currentSong: song)),
        ChangeNotifierProvider<PlaylistProvider>.value(value: playlistProvider),
        ChangeNotifierProvider<CollabPlaylistProvider>.value(value: FakeCollabPlaylistProvider()),
        ChangeNotifierProvider<LocaleProvider>.value(value: FakeLocaleProvider()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SongTile(song: song),
        ),
      ),
    );
  }

  Widget createAccountSettingsScreen() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LocaleProvider>.value(value: FakeLocaleProvider()),
        ChangeNotifierProvider<AuthProvider>.value(value: FakeAuthProvider()),
      ],
      child: const MaterialApp(
        home: AccountSettingsScreen(),
      ),
    );
  }

  group('PlayerScreen bottom action buttons tests', () {
    testWidgets('Does not render Devices button, but renders Share and Queue', (WidgetTester tester) async {
      final song = SongModel(
        id: 1,
        title: 'Song Title',
        artist: 'Artist Name',
        album: 'Album Name',
        audioUrl: 'https://example.com/song.mp3',
        duration: const Duration(seconds: 180),
        genre: 'Pop',
        createdAt: DateTime.now(),
      );
      final musicProvider = FakeMusicProvider(currentSong: song);
      final playlistProvider = FakePlaylistProvider();

      await tester.pumpWidget(createPlayerScreen(musicProvider, playlistProvider));
      await tester.pumpAndSettle();

      // Devices icon (Icons.devices) should NOT be present
      expect(find.byIcon(Icons.devices), findsNothing);

      // Share icon (Icons.share) should be present
      expect(find.byIcon(Icons.share), findsOneWidget);

      // Queue icon (Icons.queue_music) should be present
      expect(find.byIcon(Icons.queue_music), findsOneWidget);
    });

    testWidgets('Tapping Share copies song URL to clipboard and shows SnackBar', (WidgetTester tester) async {
      final song = SongModel(
        id: 1,
        title: 'Song Title',
        artist: 'Artist Name',
        album: 'Album Name',
        audioUrl: 'https://example.com/song.mp3',
        duration: const Duration(seconds: 180),
        genre: 'Pop',
        createdAt: DateTime.now(),
      );
      final musicProvider = FakeMusicProvider(currentSong: song);
      final playlistProvider = FakePlaylistProvider();

      await tester.pumpWidget(createPlayerScreen(musicProvider, playlistProvider));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.share));
      await tester.pumpAndSettle();

      // Verify URL was copied
      expect(clipboardData.length, 1);
      expect(clipboardData.first.text, 'https://krysa-music.up.railway.app/?track=1');

      // Verify SnackBar was shown
      expect(find.textContaining('скопирована'), findsOneWidget);
    });

    testWidgets('Tapping Queue displays queue dialog and changes song on item tap', (WidgetTester tester) async {
      final song1 = SongModel(
        id: 1,
        title: 'Song 1',
        artist: 'Artist 1',
        album: 'Album 1',
        audioUrl: 'https://example.com/1.mp3',
        duration: const Duration(seconds: 180),
        genre: 'Pop',
        createdAt: DateTime.now(),
      );
      final song2 = SongModel(
        id: 2,
        title: 'Song 2',
        artist: 'Artist 2',
        album: 'Album 2',
        audioUrl: 'https://example.com/2.mp3',
        duration: const Duration(seconds: 200),
        genre: 'Rock',
        createdAt: DateTime.now(),
      );

      final musicProvider = FakeMusicProvider(currentSong: song1, playlist: [song1, song2]);
      final playlistProvider = FakePlaylistProvider();

      await tester.pumpWidget(createPlayerScreen(musicProvider, playlistProvider));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.queue_music));
      await tester.pumpAndSettle();

      // Dialog / bottom sheet headers
      expect(find.text('Очередь воспроизведения'), findsOneWidget);
      expect(find.text('Сейчас играет'), findsOneWidget);
      expect(find.text('Далее'), findsOneWidget);

      // Verify songs shown in queue
      expect(find.text('Song 1'), findsNWidgets(2));
      expect(find.text('Song 2'), findsOneWidget);

      // Tap on song 2 to skip to it
      await tester.tap(find.text('Song 2'));
      await tester.pumpAndSettle();

      // Now playing should be updated to song 2
      expect(musicProvider.currentSong!.title, 'Song 2');
    });

    testWidgets('Tapping Favorite button calls PlaylistProvider.toggleFavorite, toggles state, and shows SnackBar', (WidgetTester tester) async {
      final song = SongModel(
        id: 1,
        title: 'Song Title',
        artist: 'Artist Name',
        album: 'Album Name',
        audioUrl: 'https://example.com/song.mp3',
        duration: const Duration(seconds: 180),
        genre: 'Pop',
        createdAt: DateTime.now(),
      );
      final musicProvider = FakeMusicProvider(currentSong: song);
      final playlistProvider = FakePlaylistProvider();

      await tester.pumpWidget(createPlayerScreen(musicProvider, playlistProvider));
      await tester.pumpAndSettle();

      // Should show favorite_border initially
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNothing);

      // Tap on Favorite button to add to favorite songs
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();

      // Now should show filled favorite icon
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsNothing);
      expect(playlistProvider.favoriteSongs.length, 1);
      expect(playlistProvider.favoriteSongs.first.id, 1);

      // Verify "Добавлено в избранное" SnackBar is shown
      expect(find.text('Добавлено в избранное'), findsOneWidget);

      // Dismiss SnackBar so it does not obscure the button
      ScaffoldMessenger.of(tester.element(find.byType(PlayerScreen))).hideCurrentSnackBar();
      await tester.pumpAndSettle();

      // Tap again to unfavorite
      await tester.tap(find.byIcon(Icons.favorite));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNothing);
      expect(playlistProvider.favoriteSongs.isEmpty, true);

      // Verify "Удалено из избранного" SnackBar is shown
      expect(find.text('Удалено из избранного'), findsOneWidget);
    });
  });

  group('Player and SongTile options sheets tests', () {
    testWidgets('Player Screen three-dots menu shows Go to Album, Add to Playlist and Go to Artist', (WidgetTester tester) async {
      final song = SongModel(
        id: 1,
        title: 'Song Title',
        artist: 'Artist Name',
        album: 'Album Name',
        audioUrl: 'https://example.com/song.mp3',
        duration: const Duration(seconds: 180),
        genre: 'Pop',
        createdAt: DateTime.now(),
      );
      final musicProvider = FakeMusicProvider(currentSong: song);
      final playlistProvider = FakePlaylistProvider();

      await tester.pumpWidget(createPlayerScreen(musicProvider, playlistProvider));
      await tester.pumpAndSettle();

      // Open more options menu (three dots)
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Go to album should be present
      expect(find.textContaining('альбому'), findsOneWidget);

      // Add to playlist should be present
      expect(find.textContaining('плейлист'), findsOneWidget);

      // Go to artist should be present
      expect(find.textContaining('исполнителю'), findsOneWidget);

      // Tap Add to playlist
      await tester.tap(find.textContaining('плейлист'));
      await tester.pumpAndSettle();

      // PlaylistSelectorDialog should be opened
      expect(find.byType(PlaylistSelectorDialog), findsOneWidget);
    });

    testWidgets('Player Screen three-dots menu Go to Artist navigates to ArtistProfileScreen', (WidgetTester tester) async {
      final song = SongModel(
        id: 1,
        title: 'Song Title',
        artist: 'Artist Name',
        album: 'Album Name',
        audioUrl: 'https://example.com/song.mp3',
        duration: const Duration(seconds: 180),
        genre: 'Pop',
        createdAt: DateTime.now(),
      );
      final musicProvider = FakeMusicProvider(currentSong: song);
      final playlistProvider = FakePlaylistProvider();

      await tester.pumpWidget(createPlayerScreen(musicProvider, playlistProvider));
      await tester.pumpAndSettle();

      // Open more options menu (three dots)
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Tap Go to artist
      await tester.tap(find.textContaining('исполнителю'));
      await tester.pumpAndSettle();

      // ArtistProfileScreen should be opened
      expect(find.byType(ArtistProfileScreen), findsOneWidget);
    });

    testWidgets('Player Screen three-dots menu Go to Album navigates to AlbumDetailScreen', (WidgetTester tester) async {
      final song = SongModel(
        id: 1,
        title: 'Song Title',
        artist: 'Artist Name',
        album: 'Album Name',
        audioUrl: 'https://example.com/song.mp3',
        duration: const Duration(seconds: 180),
        genre: 'Pop',
        createdAt: DateTime.now(),
      );
      final musicProvider = FakeMusicProvider(currentSong: song);
      final playlistProvider = FakePlaylistProvider();

      await tester.pumpWidget(createPlayerScreen(musicProvider, playlistProvider));
      await tester.pumpAndSettle();

      // Open more options menu (three dots)
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Tap Go to album
      await tester.tap(find.textContaining('альбому'));
      await tester.pumpAndSettle();

      // AlbumDetailScreen should be opened
      expect(find.byType(AlbumDetailScreen), findsOneWidget);
    });

    testWidgets('SongTile three-dots menu shows Go to Album, Share and Go to Artist', (WidgetTester tester) async {
      final song = SongModel(
        id: 1,
        title: 'Song Title',
        artist: 'Artist Name',
        album: 'Album Name',
        audioUrl: 'https://example.com/song.mp3',
        duration: const Duration(seconds: 180),
        genre: 'Pop',
        createdAt: DateTime.now(),
      );
      final playlistProvider = FakePlaylistProvider();

      await tester.pumpWidget(createSongTileScreen(song, playlistProvider));
      await tester.pumpAndSettle();

      // Tap more options
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Go to album should be present
      expect(find.text('Перейти к альбому'), findsOneWidget);

      // Share should be present
      expect(find.text('Поделиться'), findsOneWidget);

      // Go to artist should be present
      expect(find.text('Перейти к исполнителю'), findsOneWidget);

      // Tap Share
      await tester.tap(find.text('Поделиться'));
      await tester.pumpAndSettle();

      // Verify copied link
      expect(clipboardData.length, 1);
      expect(clipboardData.first.text, 'https://krysa-music.up.railway.app/?track=1');
      expect(find.textContaining('скопирована'), findsOneWidget);
    });

    testWidgets('SongTile three-dots menu Go to Artist navigates to ArtistProfileScreen', (WidgetTester tester) async {
      final song = SongModel(
        id: 1,
        title: 'Song Title',
        artist: 'Artist Name',
        album: 'Album Name',
        audioUrl: 'https://example.com/song.mp3',
        duration: const Duration(seconds: 180),
        genre: 'Pop',
        createdAt: DateTime.now(),
      );
      final playlistProvider = FakePlaylistProvider();

      await tester.pumpWidget(createSongTileScreen(song, playlistProvider));
      await tester.pumpAndSettle();

      // Tap more options
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Tap Go to artist
      await tester.tap(find.text('Перейти к исполнителю'));
      await tester.pumpAndSettle();

      // ArtistProfileScreen should be opened
      expect(find.byType(ArtistProfileScreen), findsOneWidget);
    });

    testWidgets('SongTile three-dots menu Go to Album navigates to AlbumDetailScreen', (WidgetTester tester) async {
      final song = SongModel(
        id: 1,
        title: 'Song Title',
        artist: 'Artist Name',
        album: 'Album Name',
        audioUrl: 'https://example.com/song.mp3',
        duration: const Duration(seconds: 180),
        genre: 'Pop',
        createdAt: DateTime.now(),
      );
      final playlistProvider = FakePlaylistProvider();

      await tester.pumpWidget(createSongTileScreen(song, playlistProvider));
      await tester.pumpAndSettle();

      // Tap more options
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Tap Go to album
      await tester.tap(find.text('Перейти к альбому'));
      await tester.pumpAndSettle();

      // AlbumDetailScreen should be opened
      expect(find.byType(AlbumDetailScreen), findsOneWidget);
    });
  });

  group('AccountSettingsScreen session termination tests', () {
    testWidgets('Tapping Terminate on active sessions deletes the session and shows SnackBar', (WidgetTester tester) async {
      final email = 'test@example.com';
      SharedPreferences.setMockInitialValues({
        'active_sessions_list_${email.toLowerCase()}': jsonEncode([
          {'id': '1', 'device': 'Safari на iPhone', 'lastActive': '2 часа назад', 'isCurrent': 'false'},
          {'id': '2', 'device': 'Firefox на Windows', 'lastActive': '1 день назад', 'isCurrent': 'false'},
          {'id': '3', 'device': 'Chrome на macOS', 'lastActive': 'Текущая', 'isCurrent': 'true'},
        ]),
      });

      await tester.pumpWidget(createAccountSettingsScreen());
      await tester.pumpAndSettle();

      // Tap on Active sessions list item
      await tester.tap(find.text('Активные сеансы'));
      await tester.pumpAndSettle();

      // Verify the sessions are listed
      expect(find.text('Safari на iPhone'), findsOneWidget);
      expect(find.text('Firefox на Windows'), findsOneWidget);

      // Find the terminate ("Завершить") buttons. The first is active/current, the next ones have terminate buttons.
      // Let's find text "Завершить" which is the term button.
      final terminateButton = find.text('Завершить').first;
      await tester.tap(terminateButton);
      await tester.pumpAndSettle();

      // The session should be terminated (removed from the list). Let's verify only one remains or Safari is gone.
      // Wait, let's verify Safari на iPhone is gone.
      expect(find.text('Safari на iPhone'), findsNothing);

      // Verify SnackBar was shown
      expect(find.textContaining('Сеанс завершен'), findsOneWidget);
    });
  });
}
