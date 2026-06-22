import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:music_app/data/models/song_model.dart';
import 'package:music_app/presentation/providers/music_provider.dart';
import 'package:music_app/presentation/providers/locale_provider.dart';
import 'package:music_app/presentation/screens/player/recently_played_screen.dart';

class FakeMusicProvider extends ChangeNotifier implements MusicProvider {
  final List<SongModel> _recentSongs;
  SongModel? playedSong;

  FakeMusicProvider(this._recentSongs);

  @override
  List<SongModel> get recentlyPlayed => _recentSongs;

  @override
  SongModel? get currentSong => null;

  @override
  Future<void> playPlaylist(List<SongModel> songs, int index) async {
    playedSong = songs[index];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeLocaleProvider extends ChangeNotifier implements LocaleProvider {
  @override
  String getString(String key) {
    if (key == 'recently_played') return 'Недавно прослушанные';
    if (key == 'no_recently_played') return 'Нет недавних треков';
    return key;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeLocaleProvider fakeLocaleProvider;

  setUp(() {
    fakeLocaleProvider = FakeLocaleProvider();
  });

  Widget createTestWidget(Widget child, MusicProvider musicProvider) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<MusicProvider>.value(value: musicProvider),
        ChangeNotifierProvider<LocaleProvider>.value(value: fakeLocaleProvider),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  testWidgets('RecentlyPlayedScreen renders empty state when history is empty', (WidgetTester tester) async {
    final fakeMusicProvider = FakeMusicProvider([]);

    await tester.pumpWidget(createTestWidget(const RecentlyPlayedScreen(), fakeMusicProvider));
    await tester.pumpAndSettle();

    expect(find.text('Недавно прослушанные'), findsOneWidget);
    expect(find.text('Нет недавних треков'), findsOneWidget);
  });

  testWidgets('RecentlyPlayedScreen renders list of songs and plays on tap', (WidgetTester tester) async {
    final testSongs = [
      SongModel(
        id: 1,
        title: 'Song A',
        artist: 'Artist A',
        album: 'Album A',
        audioUrl: 'https://example.com/a.mp3',
        duration: const Duration(seconds: 180),
        genre: 'Pop',
        createdAt: DateTime.now(),
      ),
      SongModel(
        id: 2,
        title: 'Song B',
        artist: 'Artist B',
        album: 'Album B',
        audioUrl: 'https://example.com/b.mp3',
        duration: const Duration(seconds: 210),
        genre: 'Rock',
        createdAt: DateTime.now(),
      ),
    ];
    final fakeMusicProvider = FakeMusicProvider(testSongs);

    await tester.pumpWidget(createTestWidget(const RecentlyPlayedScreen(), fakeMusicProvider));
    await tester.pumpAndSettle();

    expect(find.text('Song A'), findsOneWidget);
    expect(find.text('Song B'), findsOneWidget);

    // Tap on the first song
    await tester.tap(find.text('Song A'));
    await tester.pumpAndSettle();

    expect(fakeMusicProvider.playedSong, isNotNull);
    expect(fakeMusicProvider.playedSong!.title, 'Song A');
  });
}
