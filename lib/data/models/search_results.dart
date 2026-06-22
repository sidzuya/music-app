import 'social_user_model.dart';
import 'song_model.dart';

/// Lightweight projection of a `playlists` row used by global search.
class PlaylistSummary {
  final String id;
  final String name;
  final String? description;
  final String? coverUrl;
  final String? ownerId;
  final String? ownerUsername;

  const PlaylistSummary({
    required this.id,
    required this.name,
    this.description,
    this.coverUrl,
    this.ownerId,
    this.ownerUsername,
  });

  factory PlaylistSummary.fromMap(Map<String, dynamic> map) {
    return PlaylistSummary(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      description: map['description'] as String?,
      coverUrl: (map['cover_url'] as String?) ?? (map['cover_image'] as String?),
      ownerId: map['user_id'] as String?,
      ownerUsername: map['username'] as String?,
    );
  }
}

/// Combined results bucket returned by [SearchAggregator].
class SearchResults {
  final List<SongModel> songs;
  final List<String> artists;
  final List<PlaylistSummary> playlists;
  final List<SocialUser> profiles;

  const SearchResults({
    this.songs = const [],
    this.artists = const [],
    this.playlists = const [],
    this.profiles = const [],
  });

  static const SearchResults empty = SearchResults();

  bool get isEmpty =>
      songs.isEmpty &&
      artists.isEmpty &&
      playlists.isEmpty &&
      profiles.isEmpty;

  bool get isNotEmpty => !isEmpty;
}
