import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class SongFile {
  final String name;
  final String bucket;
  final String artist;
  final String title;
  final String? coverUrl;
  final DateTime? updatedAt;

  SongFile({
    required this.name,
    required this.bucket,
    required this.artist,
    required this.title,
    this.coverUrl,
    this.updatedAt,
  });

  String get publicUrl =>
      Supabase.instance.client.storage.from(bucket).getPublicUrl(name);

  factory SongFile.fromStorageObject(FileObject obj, String bucket) {
    final nameWithoutExt = obj.name.replaceAll(RegExp(r'\.[^.]+$'), '');
    String artist = 'Unknown';
    String title = nameWithoutExt;
    if (nameWithoutExt.contains(' - ')) {
      final parts = nameWithoutExt.split(' - ');
      artist = parts[0].trim();
      title = parts.sublist(1).join(' - ').trim();
    }
    return SongFile(
      name: obj.name,
      bucket: bucket,
      artist: artist,
      title: title,
      updatedAt: obj.updatedAt != null ? DateTime.tryParse(obj.updatedAt!) : null,
    );
  }
}

class StorageService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// Transliterate Cyrillic to Latin for safe filenames
  static String _sanitizeFileName(String input) {
    const map = {
      'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e',
      'ё': 'yo', 'ж': 'zh', 'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k',
      'л': 'l', 'м': 'm', 'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r',
      'с': 's', 'т': 't', 'у': 'u', 'ф': 'f', 'х': 'kh', 'ц': 'ts',
      'ч': 'ch', 'ш': 'sh', 'щ': 'shch', 'ъ': '', 'ы': 'y', 'ь': '',
      'э': 'e', 'ю': 'yu', 'я': 'ya',
      'А': 'A', 'Б': 'B', 'В': 'V', 'Г': 'G', 'Д': 'D', 'Е': 'E',
      'Ё': 'Yo', 'Ж': 'Zh', 'З': 'Z', 'И': 'I', 'Й': 'Y', 'К': 'K',
      'Л': 'L', 'М': 'M', 'Н': 'N', 'О': 'O', 'П': 'P', 'Р': 'R',
      'С': 'S', 'Т': 'T', 'У': 'U', 'Ф': 'F', 'Х': 'Kh', 'Ц': 'Ts',
      'Ч': 'Ch', 'Ш': 'Sh', 'Щ': 'Shch', 'Ъ': '', 'Ы': 'Y', 'Ь': '',
      'Э': 'E', 'Ю': 'Yu', 'Я': 'Ya',
      'қ': 'q', 'Қ': 'Q', 'ң': 'ng', 'Ң': 'Ng', 'ү': 'u', 'Ү': 'U',
      'ұ': 'u', 'Ұ': 'U', 'һ': 'h', 'Һ': 'H', 'ә': 'a', 'Ә': 'A',
      'і': 'i', 'І': 'I', 'ө': 'o', 'Ө': 'O',
    };
    final buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final char = input[i];
      buffer.write(map[char] ?? char);
    }
    // Remove any remaining non-ASCII and unsafe chars
    return buffer.toString().replaceAll(RegExp(r'[^\w\s\-.]'), '').trim();
  }

  static Future<List<SongFile>> listSongs(String bucket) async {
    try {
      final files = await _client.storage.from(bucket).list(
            path: '',
            searchOptions: const SearchOptions(limit: 1000),
          );
      return files
          .where((f) => f.name.isNotEmpty && !f.name.startsWith('.'))
          .map((f) => SongFile.fromStorageObject(f, bucket))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<List<SongFile>> listAllSongs() async {
    final results = await Future.wait([
      listSongs('songs'),
      listSongs('featured'),
    ]);
    return [...results[0], ...results[1]];
  }

  static Future<bool> uploadSong({
    required String bucket,
    required String artist,
    required String title,
    required Uint8List fileBytes,
    required String fileExtension,
  }) async {
    final safeArtist = _sanitizeFileName(artist);
    final safeTitle = _sanitizeFileName(title);
    final fileName = '$safeArtist - $safeTitle.$fileExtension';
    try {
      await _client.storage.from(bucket).uploadBinary(
            fileName,
            fileBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      // If uploading to featured, also save to featured_songs table
      if (bucket == 'featured') {
        await _client.from('featured_songs').insert({
          'title': title,
          'artist': artist,
          'album': null,
          'genre': null,
        });
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> uploadCover({
    required String songFileName,
    required Uint8List bytes,
    required String extension,
  }) async {
    final baseName = _sanitizeFileName(songFileName.replaceAll(RegExp(r'\.[^.]+$'), ''));
    final coverName = '$baseName.$extension';
    try {
      await _client.storage.from('covers').uploadBinary(
            coverName,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteSong(String bucket, String fileName) async {
    try {
      await _client.storage.from(bucket).remove([fileName]);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> moveSong(String fileName, String fromBucket, String toBucket) async {
    try {
      final bytes = await _client.storage.from(fromBucket).download(fileName);
      await _client.storage.from(toBucket).uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      await _client.storage.from(fromBucket).remove([fileName]);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, int>> getStats() async {
    int songsCount = 0;
    int featuredCount = 0;
    int usersCount = 0;
    int playlistsCount = 0;

    try {
      final songs = await _client.storage.from('songs').list(
            searchOptions: const SearchOptions(limit: 1000),
          );
      songsCount = songs.where((f) => f.name.isNotEmpty && !f.name.startsWith('.')).length;
    } catch (_) {}

    try {
      final featured = await _client.storage.from('featured').list(
            searchOptions: const SearchOptions(limit: 1000),
          );
      featuredCount = featured.where((f) => f.name.isNotEmpty && !f.name.startsWith('.')).length;
    } catch (_) {}

    try {
      final profiles = await _client.from('profiles').select('id');
      usersCount = (profiles as List).length;
    } catch (_) {}

    try {
      final playlists = await _client.from('playlists').select('id');
      playlistsCount = (playlists as List).length;
    } catch (_) {}

    return {
      'songs': songsCount,
      'featured': featuredCount,
      'users': usersCount,
      'playlists': playlistsCount,
    };
  }
}
