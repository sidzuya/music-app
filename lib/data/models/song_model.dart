class SongModel {
  final int? id;
  final String? backendId;
  final String title;
  final String artist;
  final String album;
  final String? albumArt;
  final String? audioUrl;
  final Duration duration;
  final String genre;
  final DateTime createdAt;
  final bool isFavorite;

  SongModel({
    this.id,
    this.backendId,
    required this.title,
    required this.artist,
    required this.album,
    this.albumArt,
    this.audioUrl,
    required this.duration,
    required this.genre,
    required this.createdAt,
    this.isFavorite = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'backend_id': backendId,
      'title': title,
      'artist': artist,
      'album': album,
      'album_art': albumArt,
      'audio_url': audioUrl,
      'duration_seconds': duration.inSeconds,
      'genre': genre,
      'created_at': createdAt.toIso8601String(),
      'is_favorite': isFavorite ? 1 : 0,
    };
  }

  factory SongModel.fromMap(Map<String, dynamic> map) {
    return SongModel(
      id: map['id']?.toInt(),
      backendId: map['backend_id'] as String?,
      title: map['title'] ?? '',
      artist: map['artist'] ?? '',
      album: map['album'] ?? '',
      albumArt: map['album_art'],
      audioUrl: map['audio_url'],
      duration: Duration(seconds: map['duration_seconds'] ?? 0),
      genre: map['genre'] ?? '',
      createdAt: DateTime.parse(map['created_at']),
      isFavorite: (map['is_favorite'] ?? 0) == 1,
    );
  }

  SongModel copyWith({
    int? id,
    String? backendId,
    String? title,
    String? artist,
    String? album,
    String? albumArt,
    String? audioUrl,
    Duration? duration,
    String? genre,
    DateTime? createdAt,
    bool? isFavorite,
  }) {
    return SongModel(
      id: id ?? this.id,
      backendId: backendId ?? this.backendId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArt: albumArt ?? this.albumArt,
      audioUrl: audioUrl ?? this.audioUrl,
      duration: duration ?? this.duration,
      genre: genre ?? this.genre,
      createdAt: createdAt ?? this.createdAt,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  String get formattedDuration {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  String toString() {
    return 'SongModel(id: $id, title: $title, artist: $artist, album: $album, duration: $duration, genre: $genre, isFavorite: $isFavorite)';
  }
}
