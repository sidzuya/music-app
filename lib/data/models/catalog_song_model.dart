import 'song_model.dart';

/// Row from `public.songs` (extended catalog with owner/status/featured).
enum SongStatus { pending, approved, rejected }

SongStatus _songStatusFromString(String? raw) {
  switch (raw) {
    case 'approved':
      return SongStatus.approved;
    case 'rejected':
      return SongStatus.rejected;
    default:
      return SongStatus.pending;
  }
}

class CatalogSong {
  final String id;
  final String title;
  final String artist;
  final String audioUrl;
  final String? coverUrl;
  final String? album;
  final String? genre;
  final int? durationSeconds;
  final String? ownerId;
  final SongStatus status;
  final bool isFeatured;
  final String? reviewNote;
  final String? reviewerId;
  final DateTime createdAt;
  final DateTime? approvedAt;

  const CatalogSong({
    required this.id,
    required this.title,
    required this.artist,
    required this.audioUrl,
    required this.status,
    required this.isFeatured,
    required this.createdAt,
    this.coverUrl,
    this.album,
    this.genre,
    this.durationSeconds,
    this.ownerId,
    this.reviewNote,
    this.reviewerId,
    this.approvedAt,
  });

  factory CatalogSong.fromMap(Map<String, dynamic> map) {
    return CatalogSong(
      id: map['id'] as String,
      title: (map['title'] ?? '') as String,
      artist: (map['artist'] ?? '') as String,
      audioUrl: (map['audio_url'] ?? '') as String,
      coverUrl: map['cover_url'] as String?,
      album: map['album'] as String?,
      genre: map['genre'] as String?,
      durationSeconds: map['duration_seconds'] as int?,
      ownerId: map['owner_id'] as String?,
      status: _songStatusFromString(map['status'] as String?),
      isFeatured: (map['is_featured'] as bool?) ?? false,
      reviewNote: map['review_note'] as String?,
      reviewerId: map['reviewer_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      approvedAt: map['approved_at'] != null
          ? DateTime.parse(map['approved_at'] as String)
          : null,
    );
  }

  String get statusLabel {
    switch (status) {
      case SongStatus.pending:
        return 'На модерации';
      case SongStatus.approved:
        return 'Опубликовано';
      case SongStatus.rejected:
        return 'Отклонено';
    }
  }

  SongModel toSongModel() {
    return SongModel(
      backendId: id,
      title: title,
      artist: artist,
      album: album ?? '',
      albumArt: coverUrl,
      audioUrl: audioUrl,
      duration: Duration(seconds: durationSeconds ?? 0),
      genre: genre ?? '',
      createdAt: createdAt,
    );
  }
}
