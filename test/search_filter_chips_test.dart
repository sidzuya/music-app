import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:music_app/data/models/search_results.dart';
import 'package:music_app/data/models/song_model.dart';
import 'package:music_app/data/models/social_user_model.dart';
import 'package:music_app/data/models/playlist_model.dart';
import 'package:music_app/data/services/search_aggregator.dart';
import 'package:music_app/presentation/providers/music_provider.dart';
import 'package:music_app/presentation/providers/locale_provider.dart';
import 'package:music_app/presentation/providers/playlist_provider.dart';
import 'package:music_app/presentation/providers/collab_playlist_provider.dart';
import 'package:music_app/presentation/providers/follow_provider.dart';
import 'package:music_app/presentation/screens/search/search_screen.dart';
import 'package:music_app/presentation/widgets/song_tile.dart';
import 'package:music_app/presentation/widgets/user_tile.dart';

class FakeMusicProvider extends ChangeNotifier implements MusicProvider {
  SongModel? _currentSong;
  List<SongModel> _playlist = [];
  bool _isPlaying = false;
  int _currentIndex = 0;
  List<SongModel> _recentlyPlayed = [];

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
    _isPlaying = true;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakePlaylistProvider extends ChangeNotifier implements PlaylistProvider {
  final List<SongModel> _favoriteSongs = [];

  @override
  List<SongModel> get favoriteSongs => _favoriteSongs;

  @override
  bool isFavorite(SongModel song) => _favoriteSongs.any((s) => s.id == song.id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCollabPlaylistProvider extends ChangeNotifier implements CollabPlaylistProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFollowProvider extends ChangeNotifier implements FollowProvider {
  @override
  bool isFollowing(String userId) => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeLocaleProvider extends ChangeNotifier implements LocaleProvider {
  @override
  String getString(String key) {
    switch (key) {
      case 'search':
        return 'Поиск';
      case 'section_songs':
        return 'Треки';
      case 'section_artists':
        return 'Исполнители';
      case 'section_playlists':
        return 'Плейлисты';
      case 'section_profiles':
        return 'Профили';
      case 'no_results':
        return 'Ничего не найдено';
      case 'try_different_search':
        return 'Попробуйте другой запрос';
      case 'follow':
        return 'Подписаться';
      case 'following_button':
        return 'Вы подписаны';
      default:
        return key;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    // Initialize Supabase with placeholder values to prevent assertion error in UserTile
    await Supabase.initialize(
      url: 'https://placeholder.supabase.co',
      anonKey: 'placeholder-key',
    );
  });

  Widget createSearchScreen(
    SearchAggregator aggregator,
    FakeMusicProvider musicProvider,
    FakePlaylistProvider playlistProvider,
    FakeFollowProvider followProvider,
  ) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<MusicProvider>.value(value: musicProvider),
        ChangeNotifierProvider<PlaylistProvider>.value(value: playlistProvider),
        ChangeNotifierProvider<CollabPlaylistProvider>.value(value: FakeCollabPlaylistProvider()),
        ChangeNotifierProvider<FollowProvider>.value(value: followProvider),
        ChangeNotifierProvider<LocaleProvider>.value(value: FakeLocaleProvider()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SearchScreen(aggregator: aggregator),
        ),
      ),
    );
  }

  group('SearchScreen Category Filter Chips Tests', () {
    late FakeMusicProvider musicProvider;
    late FakePlaylistProvider playlistProvider;
    late FakeFollowProvider followProvider;
    late SearchAggregator testAggregator;

    setUp(() {
      musicProvider = FakeMusicProvider();
      playlistProvider = FakePlaylistProvider();
      followProvider = FakeFollowProvider();

      final testSongs = [
        SongModel(
          id: 1,
          title: 'Awesome Song',
          artist: 'Best Artist',
          album: 'Great Album',
          duration: const Duration(seconds: 200),
          genre: 'Rock',
          createdAt: DateTime.now(),
          audioUrl: 'https://example.com/awesome.mp3',
        ),
      ];

      final testPlaylists = [
        const PlaylistSummary(
          id: 'p1',
          name: 'Cool Playlist',
          ownerUsername: 'user1',
        ),
      ];

      final testProfiles = [
        const SocialUser(
          id: 'u1',
          username: 'Cool User',
        ),
      ];

      testAggregator = SearchAggregator(
        searchSongs: (q) async => testSongs,
        searchPlaylists: (q) async => testPlaylists,
        searchProfiles: (q) async => testProfiles,
      );
    });

    testWidgets('Renders all filter chips after performing a search', (WidgetTester tester) async {
      await tester.pumpWidget(createSearchScreen(testAggregator, musicProvider, playlistProvider, followProvider));
      await tester.pumpAndSettle();

      // Enter search query 'best'
      final searchInput = find.byType(TextField);
      expect(searchInput, findsOneWidget);
      await tester.enterText(searchInput, 'best');
      
      // Wait for debounce timer (400ms)
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Filter chips should be rendered
      expect(find.widgetWithText(ChoiceChip, 'Все'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Треки'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Исполнители'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Плейлисты'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Профили'), findsOneWidget);

      // In "Все" (All) category:
      // - SongTile "Awesome Song" is at the bottom, so we verify upper widgets, scroll, then verify "Awesome Song"
      expect(find.text('Cool User'), findsOneWidget);
      expect(find.text('Cool Playlist'), findsOneWidget);

      // Scroll down to bring songs section into view
      final verticalListView = find.byWidgetPredicate(
        (w) => w is ListView && w.scrollDirection == Axis.vertical,
      );
      expect(verticalListView, findsOneWidget);
      await tester.drag(verticalListView, const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text('Awesome Song'), findsOneWidget);
    });

    testWidgets('Tapping on a category filter chip filters results', (WidgetTester tester) async {
      await tester.pumpWidget(createSearchScreen(testAggregator, musicProvider, playlistProvider, followProvider));
      await tester.pumpAndSettle();

      // Enter search query 'best'
      await tester.enterText(find.byType(TextField), 'best');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Verify profile is visible (at the top)
      expect(find.text('Cool User'), findsOneWidget);

      // Tap on "Треки" (Songs) filter chip
      await tester.tap(find.widgetWithText(ChoiceChip, 'Треки'));
      await tester.pumpAndSettle();

      // Only songs (and their subtitles) should be visible (fully in view since profiles are hidden)
      expect(find.text('Awesome Song'), findsOneWidget);
      expect(find.text('Best Artist'), findsOneWidget); // SongTile subtitle only
      expect(find.text('Cool Playlist'), findsNothing);
      expect(find.text('Cool User'), findsNothing);

      // Tap on "Исполнители" (Artists) filter chip
      await tester.tap(find.widgetWithText(ChoiceChip, 'Исполнители'));
      await tester.pumpAndSettle();

      // Only standalone artist tiles should be visible
      expect(find.text('Awesome Song'), findsNothing);
      expect(find.text('Best Artist'), findsOneWidget); // Artist ListTile only
      expect(find.text('Cool Playlist'), findsNothing);
      expect(find.text('Cool User'), findsNothing);

      // Tap on "Профили" (Profiles) filter chip
      await tester.tap(find.widgetWithText(ChoiceChip, 'Профили'));
      await tester.pumpAndSettle();

      // Only profiles/users should be visible
      expect(find.text('Awesome Song'), findsNothing);
      expect(find.text('Best Artist'), findsNothing);
      expect(find.text('Cool Playlist'), findsNothing);
      expect(find.text('Cool User'), findsOneWidget);

      // Tap on "Все" (All) filter chip
      await tester.tap(find.widgetWithText(ChoiceChip, 'Все'));
      await tester.pumpAndSettle();

      // All should be back: profiles at top, songs at bottom (scroll to verify)
      expect(find.text('Cool User'), findsOneWidget);
      expect(find.text('Cool Playlist'), findsOneWidget);

      final verticalListView = find.byWidgetPredicate(
        (w) => w is ListView && w.scrollDirection == Axis.vertical,
      );
      await tester.drag(verticalListView, const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text('Awesome Song'), findsOneWidget);
    });
  });
}
