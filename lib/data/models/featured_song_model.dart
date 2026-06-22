import 'package:supabase_flutter/supabase_flutter.dart';

/// Model representing a featured song from Supabase database
class FeaturedSong {
  final String id;
  final String title;
  final String artist;
  final String? album;
  final String? genre;
  final int durationSeconds;
  final String? albumArtUrl;
  final String storagePath;
  final String category; // 'popular', 'recent', 'recommended'
  final DateTime createdAt;

  // Cached public URL for audio playback
  String? _audioUrl;

  FeaturedSong({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.genre,
    this.durationSeconds = 0,
    this.albumArtUrl,
    required this.storagePath,
    required this.category,
    required this.createdAt,
  });

  /// Create from Supabase database row
  factory FeaturedSong.fromMap(Map<String, dynamic> map) {
    return FeaturedSong(
      id: map['id'] as String,
      title: map['title'] as String,
      artist: map['artist'] as String,
      album: map['album'] as String?,
      genre: map['genre'] as String?,
      durationSeconds: map['duration_seconds'] as int? ?? 0,
      albumArtUrl: map['album_art_url'] as String?,
      storagePath: map['storage_path'] as String,
      category: map['category'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Get duration as Duration object
  Duration get duration => Duration(seconds: durationSeconds);

  /// Get the public URL for audio playback
  String getPublicUrl(String bucketName) {
    if (_audioUrl != null) return _audioUrl!;
    
    _audioUrl = Supabase.instance.client.storage
        .from(bucketName)
        .getPublicUrl(storagePath);
    
    return _audioUrl!;
  }

  /// Convert to Map for database operations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'genre': genre,
      'duration_seconds': durationSeconds,
      'album_art_url': albumArtUrl,
      'storage_path': storagePath,
      'category': category,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'FeaturedSong(title: $title, artist: $artist, category: $category)';
  }
}
