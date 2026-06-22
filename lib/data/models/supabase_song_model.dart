/// Model representing a song stored in Supabase Storage
class SupabaseSong {
  final String id;
  final String fileName;
  final String title;
  final String artist;
  final String audioUrl;
  final String? coverUrl;
  final DateTime uploadedAt;
  final int? sizeBytes;

  SupabaseSong({
    required this.id,
    required this.fileName,
    required this.title,
    required this.artist,
    required this.audioUrl,
    this.coverUrl,
    required this.uploadedAt,
    this.sizeBytes,
  });

  /// Parse song metadata from file name
  /// Supports formats:
  /// - "Artist - Title.mp3"
  /// - "Title.mp3" (artist will be "Unknown Artist")
  factory SupabaseSong.fromStorageFile({
    required String id,
    required String fileName,
    required String audioUrl,
    required DateTime uploadedAt,
    int? sizeBytes,
  }) {
    String title;
    String artist;

    // Remove file extension
    final nameWithoutExtension = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');

    // Try to parse "Artist - Title" format
    if (nameWithoutExtension.contains(' - ')) {
      final parts = nameWithoutExtension.split(' - ');
      artist = parts[0].trim();
      title = parts.sublist(1).join(' - ').trim();
    } else {
      title = nameWithoutExtension;
      artist = 'Unknown Artist';
    }

    return SupabaseSong(
      id: id,
      fileName: fileName,
      title: title,
      artist: artist,
      audioUrl: audioUrl,
      uploadedAt: uploadedAt,
      sizeBytes: sizeBytes,
    );
  }

  /// Format file size for display
  String get formattedSize {
    if (sizeBytes == null) return '';
    
    final kb = sizeBytes! / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
  
  /// Create a copy with updated fields
  SupabaseSong copyWith({
    String? id,
    String? fileName,
    String? title,
    String? artist,
    String? audioUrl,
    String? coverUrl,
    DateTime? uploadedAt,
    int? sizeBytes,
  }) {
    return SupabaseSong(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      audioUrl: audioUrl ?? this.audioUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      sizeBytes: sizeBytes ?? this.sizeBytes,
    );
  }

  @override
  String toString() {
    return 'SupabaseSong(id: $id, title: $title, artist: $artist)';
  }
}
