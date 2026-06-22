import 'song_model.dart';

class RecommendationMixModel {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final List<SongModel> songs;

  const RecommendationMixModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.songs,
  });

  String? get coverImage {
    for (final song in songs) {
      if (song.albumArt != null && song.albumArt!.isNotEmpty) {
        return song.albumArt;
      }
    }
    return null;
  }
}
