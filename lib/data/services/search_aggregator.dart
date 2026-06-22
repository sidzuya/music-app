import 'package:flutter/foundation.dart';

import '../models/search_results.dart';
import '../models/social_user_model.dart';
import '../models/song_model.dart';

typedef SongsLookup = Future<List<SongModel>> Function(String query);
typedef PlaylistsLookup = Future<List<PlaylistSummary>> Function(String query);
typedef ProfilesLookup = Future<List<SocialUser>> Function(String query);

/// Composes the global search across multiple sources (songs, playlists,
/// profiles) and derives the artist bucket from song results. Network and
/// database calls are injected so the aggregator stays trivially testable.
class SearchAggregator {
  final SongsLookup searchSongs;
  final PlaylistsLookup searchPlaylists;
  final ProfilesLookup searchProfiles;

  const SearchAggregator({
    required this.searchSongs,
    required this.searchPlaylists,
    required this.searchProfiles,
  });

  Future<SearchResults> search(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) return SearchResults.empty;

    final songsFuture = _safe<List<SongModel>>(
      () => searchSongs(query),
      fallback: const <SongModel>[],
      label: 'songs',
    );
    final playlistsFuture = _safe<List<PlaylistSummary>>(
      () => searchPlaylists(query),
      fallback: const <PlaylistSummary>[],
      label: 'playlists',
    );
    final profilesFuture = _safe<List<SocialUser>>(
      () => searchProfiles(query),
      fallback: const <SocialUser>[],
      label: 'profiles',
    );

    final results = await Future.wait([
      songsFuture,
      playlistsFuture,
      profilesFuture,
    ]);

    final songs = results[0] as List<SongModel>;
    final playlists = results[1] as List<PlaylistSummary>;
    final profiles = results[2] as List<SocialUser>;

    final artists = deriveArtistsForUi(songs, query);

    return SearchResults(
      songs: songs,
      artists: artists,
      playlists: playlists,
      profiles: profiles,
    );
  }

  /// Pull unique artists from [songs] whose name matches the [query]
  /// (case-insensitive substring), preserving the order in which they appear.
  static List<String> deriveArtistsForUi(List<SongModel> songs, String query) {
    final normalisedQuery = query.toLowerCase();
    final seen = <String>{};
    final ordered = <String>[];
    for (final song in songs) {
      final artist = song.artist.trim();
      if (artist.isEmpty) continue;
      if (!artist.toLowerCase().contains(normalisedQuery)) continue;
      if (seen.add(artist.toLowerCase())) {
        ordered.add(artist);
      }
    }
    return ordered;
  }

  static Future<T> _safe<T>(
    Future<T> Function() body, {
    required T fallback,
    required String label,
  }) async {
    try {
      return await body();
    } catch (e, st) {
      debugPrint('SearchAggregator.$label failed: $e\n$st');
      return fallback;
    }
  }
}
