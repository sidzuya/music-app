import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/supabase_song_model.dart';

/// Service for interacting with Supabase Storage
class SupabaseService {
  static const String supabaseUrl = 'https://yxxlbkvvdxgcoyrpydko.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl4eGxia3Z2ZHhnY295cnB5ZGtvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk2OTQ4NzMsImV4cCI6MjA4NTI3MDg3M30.J_UskkveTUrfv69QXUIyo4IIYMXLJpDDr887qyVn9tE';
  
  /// Name of the storage bucket containing songs
  /// Change this to match your bucket name in Supabase
  static const String bucketName = 'songs';

  static SupabaseService? _instance;
  
  SupabaseService._();
  
  static SupabaseService get instance {
    _instance ??= SupabaseService._();
    return _instance!;
  }

  /// Get Supabase client
  SupabaseClient get _client => Supabase.instance.client;

  /// Initialize Supabase
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  /// Get all songs from Supabase Storage bucket
  Future<List<SupabaseSong>> getSongs() async {
    try {
      // List songs and covers in parallel
      final results = await Future.wait([
        _client.storage.from(bucketName).list(),
        _client.storage.from('covers').list(),
      ]);
      final List<FileObject> files = results[0];
      final List<FileObject> coverFiles = results[1];

      // Build cover map by basename
      final coverMap = <String, String>{};
      for (final c in coverFiles) {
        final base = c.name.replaceAll(RegExp(r'\.[^.]+$'), '').toLowerCase();
        coverMap[base] = _client.storage.from('covers').getPublicUrl(c.name);
      }

      // Filter only audio files
      final audioFiles = files.where((file) {
        final ext = file.name.toLowerCase();
        return ext.endsWith('.mp3') || 
               ext.endsWith('.m4a') || 
               ext.endsWith('.wav') ||
               ext.endsWith('.flac') ||
               ext.endsWith('.aac');
      }).toList();

      // Convert to SupabaseSong models
      final songs = audioFiles.map((file) {
        final audioUrl = getPublicUrl(file.name);
        final song = SupabaseSong.fromStorageFile(
          id: file.id ?? file.name,
          fileName: file.name,
          audioUrl: audioUrl,
          uploadedAt: file.createdAt != null 
              ? DateTime.parse(file.createdAt!) 
              : DateTime.now(),
          sizeBytes: file.metadata?['size'] as int?,
        );
        // Match cover by filename basename
        final base = file.name.replaceAll(RegExp(r'\.[^.]+$'), '').toLowerCase();
        return song.copyWith(coverUrl: coverMap[base]);
      }).toList();

      // Sort by upload date (newest first)
      songs.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

      return songs;
    } catch (e, stackTrace) {
      print('Error fetching songs from Supabase: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Get songs from a specific folder in the bucket
  Future<List<SupabaseSong>> getSongsFromFolder(String folderPath) async {
    try {
      final List<FileObject> files = await _client.storage
          .from(bucketName)
          .list(path: folderPath);

      final audioFiles = files.where((file) {
        final ext = file.name.toLowerCase();
        return ext.endsWith('.mp3') || 
               ext.endsWith('.m4a') || 
               ext.endsWith('.wav') ||
               ext.endsWith('.flac') ||
               ext.endsWith('.aac');
      }).toList();

      final songs = audioFiles.map((file) {
        final fullPath = '$folderPath/${file.name}';
        final audioUrl = getPublicUrl(fullPath);
        
        return SupabaseSong.fromStorageFile(
          id: file.id ?? file.name,
          fileName: file.name,
          audioUrl: audioUrl,
          uploadedAt: file.createdAt != null 
              ? DateTime.parse(file.createdAt!) 
              : DateTime.now(),
          sizeBytes: file.metadata?['size'] as int?,
        );
      }).toList();

      songs.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

      return songs;
    } catch (e) {
      print('Error fetching songs from folder: $e');
      return [];
    }
  }

  /// Get public URL for a file in the bucket
  String getPublicUrl(String filePath) {
    return _client.storage.from(bucketName).getPublicUrl(filePath);
  }

  /// Search songs by title or artist
  Future<List<SupabaseSong>> searchSongs(String query) async {
    final allSongs = await getSongs();
    final lowerQuery = query.toLowerCase();
    
    return allSongs.where((song) {
      return song.title.toLowerCase().contains(lowerQuery) ||
             song.artist.toLowerCase().contains(lowerQuery);
    }).toList();
  }
}
