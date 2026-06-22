import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/data/models/search_results.dart';
import 'package:music_app/data/models/social_user_model.dart';
import 'package:music_app/data/models/song_model.dart';
import 'package:music_app/data/services/search_aggregator.dart';

SongModel _song(String title, String artist, {String genre = 'rock'}) {
  return SongModel(
    title: title,
    artist: artist,
    album: 'Album',
    duration: const Duration(seconds: 180),
    genre: genre,
    createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
  );
}

void main() {
  group('SearchAggregator', () {
    test(
      'aggregates songs, derived artists, playlists and profiles for a query',
      () async {
        final aggregator = SearchAggregator(
          searchSongs: (q) async {
            expect(q, 'rock');
            return [
              _song('Smells Like Rock', 'Rock King'),
              _song('Rock Anthem', 'Rock Queen'),
              _song('Rock Anthem (Live)', 'Rock Queen'), // duplicate artist
              _song('Mellow Jazz', 'Jazz Master', genre: 'jazz'),
            ];
          },
          searchPlaylists: (q) async {
            expect(q, 'rock');
            return [
              const PlaylistSummary(
                id: 'p1',
                name: 'Best Rock Anthems',
                ownerUsername: 'alice',
              ),
            ];
          },
          searchProfiles: (q) async {
            expect(q, 'rock');
            return const [
              SocialUser(id: 'u1', username: 'rockstar'),
            ];
          },
        );

        final results = await aggregator.search('rock');

        expect(results.songs, hasLength(4));
        expect(results.playlists.single.name, 'Best Rock Anthems');
        expect(results.profiles.single.username, 'rockstar');
        // Artists derived from songs whose artist matches the query, deduped,
        // preserving insertion order. 'Jazz Master' does not contain "rock".
        expect(results.artists, ['Rock King', 'Rock Queen']);
        expect(results.isEmpty, isFalse);
      },
    );

    test('empty / whitespace query returns empty results without calling subservices',
        () async {
      var calls = 0;
      final aggregator = SearchAggregator(
        searchSongs: (q) async {
          calls++;
          return const [];
        },
        searchPlaylists: (q) async {
          calls++;
          return const [];
        },
        searchProfiles: (q) async {
          calls++;
          return const [];
        },
      );

      final r = await aggregator.search('   ');
      expect(r.isEmpty, isTrue);
      expect(r.songs, isEmpty);
      expect(r.artists, isEmpty);
      expect(r.playlists, isEmpty);
      expect(r.profiles, isEmpty);
      expect(calls, 0);
    });

    test('failures in any source degrade gracefully (returns empty for that bucket)',
        () async {
      final aggregator = SearchAggregator(
        searchSongs: (q) async => [_song('Hit', 'Star')],
        searchPlaylists: (q) async => throw Exception('db down'),
        searchProfiles: (q) async => throw Exception('rls'),
      );

      final results = await aggregator.search('star');
      expect(results.songs, hasLength(1));
      expect(results.artists, ['Star']);
      expect(results.playlists, isEmpty);
      expect(results.profiles, isEmpty);
    });
  });
}
