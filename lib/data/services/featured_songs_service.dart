import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/supabase_song_model.dart';

/// Service for fetching featured songs directly from Supabase Storage bucket
/// Works exactly like SupabaseService but uses 'featured' bucket
class FeaturedSongsService {
  static const String bucketName = 'featured';

  static FeaturedSongsService? _instance;

  FeaturedSongsService._();

  static FeaturedSongsService get instance {
    _instance ??= FeaturedSongsService._();
    return _instance!;
  }

  SupabaseClient get _client => Supabase.instance.client;
  
  /// Map of song titles (lowercase) to cover image URLs
  static const Map<String, String> _coverMap = {
    'church': 'https://i.scdn.co/image/ab67616d0000b273601eb33454f13f26db9084e4',
    'heaven and back': 'https://c.saavncdn.com/297/PHASES-English-2019-20190607041429-500x500.jpg',
    'meddle about': 'https://i.scdn.co/image/ab67616d0000b27359f568f60df2311353f97db5',
    'right here': 'https://i.scdn.co/image/ab67616d00001e0298aa564c5baf1a2852aae072',
    'apocalypse': 'https://c.saavncdn.com/759/Apocalypse-Cigarettes-After-Sex-Instrumental-Cover-Instrumental-2024-20241209202141-500x500.jpg',
    'cry': 'https://f4.bcbits.com/img/a0119125934_10.jpg',
    'midwest emo version': 'https://cdn-images.dzcdn.net/images/cover/c29bd0166668f0630725185a1fe8bb4f/0x1900-000000-80-0-0.jpg',
    'proderics stranger ft melodybloom': 'https://i.scdn.co/image/ab67616d0000b2735055779e7605a859972f6f0c',
    'proderics strangers ft melodybloom': 'https://i.scdn.co/image/ab67616d0000b2735055779e7605a859972f6f0c',
    'loving machine': 'https://cdn-image.zvuk.com/pic?hash=9b364bb8-a04c-4c46-b2d1-873f5941c7d6&id=40217275&size=large&type=release',
    'seasons': 'https://i.scdn.co/image/ab67616d0000b2733f203b8d0d8e54fab416a825',
  };
  
  /// Get cover URL for a song title
  String? getCoverForTitle(String title) {
    final lowerTitle = title.toLowerCase();
    
    // First try exact match
    if (_coverMap.containsKey(lowerTitle)) {
      return _coverMap[lowerTitle];
    }
    
    // Then try partial match
    for (final entry in _coverMap.entries) {
      if (lowerTitle.contains(entry.key) || entry.key.contains(lowerTitle)) {
        return entry.value;
      }
    }
    
    return null;
  }

  /// Get all songs from featured bucket (recent section)
  Future<List<SupabaseSong>> getRecentSongs({int limit = 5}) async {
    try {
      final songs = await getAllSongsFromBucket();
      // Take first N songs for "recent"
      return songs.take(limit).toList();
    } catch (e) {
      print('Error fetching recent songs: $e');
      return [];
    }
  }

  /// Get all songs from featured bucket (popular section)
  Future<List<SupabaseSong>> getPopularSongs({int limit = 6}) async {
    try {
      final songs = await getAllSongsFromBucket();
      // For popular, we can reverse or shuffle - here just take from end
      if (songs.length > limit) {
        return songs.sublist(songs.length - limit);
      }
      return songs;
    } catch (e) {
      print('Error fetching popular songs: $e');
      return [];
    }
  }

  /// Get all songs from the featured bucket
  Future<List<SupabaseSong>> getAllSongsFromBucket() async {
    try {
      print('FeaturedSongsService: Fetching songs from bucket: $bucketName');

      // List all files in the bucket and covers in parallel
      final results = await Future.wait([
        _client.storage.from(bucketName).list(),
        _client.storage.from('covers').list(),
      ]);
      final List<FileObject> files = results[0];
      final List<FileObject> coverFiles = results[1];

      // Build map: basename (without ext) -> cover public URL
      final coverMap = <String, String>{};
      for (final c in coverFiles) {
        final base = c.name.replaceAll(RegExp(r'\.[^.]+$'), '').toLowerCase();
        coverMap[base] = _client.storage.from('covers').getPublicUrl(c.name);
      }

      print('FeaturedSongsService: Found ${files.length} total files, ${coverFiles.length} covers');

      // Filter only audio files
      final audioFiles = files.where((file) {
        final name = file.name.toLowerCase();
        return name.endsWith('.mp3') || 
               name.endsWith('.m4a') || 
               name.endsWith('.wav') ||
               name.endsWith('.aac') ||
               name.endsWith('.flac');
      }).toList();

      // Convert to SupabaseSong objects with covers
      final songs = audioFiles.map((file) {
        final audioUrl = _client.storage
            .from(bucketName)
            .getPublicUrl(file.name);
        
        final song = SupabaseSong.fromStorageFile(
          id: file.id ?? file.name,
          fileName: file.name,
          audioUrl: audioUrl,
          uploadedAt: file.updatedAt != null 
              ? DateTime.parse(file.updatedAt!) 
              : DateTime.now(),
          sizeBytes: file.metadata?['size'] as int?,
        );
        
        // Match cover by filename basename, fallback to hardcoded title map
        final base = file.name.replaceAll(RegExp(r'\.[^.]+$'), '').toLowerCase();
        final coverUrl = coverMap[base] ?? getCoverForTitle(song.title);
        return song.copyWith(coverUrl: coverUrl);
      }).toList();

      // Sort newest first
      songs.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

      return songs;
    } catch (e) {
      print('Error fetching songs from featured bucket: $e');
      return [];
    }
  }

  /// Search songs in featured bucket
  Future<List<SupabaseSong>> searchSongs(String query) async {
    if (query.isEmpty) return [];

    try {
      final allSongs = await getAllSongsFromBucket();
      final lowerQuery = query.toLowerCase();
      
      return allSongs.where((song) =>
        song.title.toLowerCase().contains(lowerQuery) ||
        song.artist.toLowerCase().contains(lowerQuery)
      ).toList();
    } catch (e) {
      print('Error searching featured songs: $e');
      return [];
    }
  }
}
