import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class AdminSongFile {
  final String name;
  final String bucket;
  final String artist;
  final String title;
  final DateTime? updatedAt;

  const AdminSongFile({
    required this.name,
    required this.bucket,
    required this.artist,
    required this.title,
    this.updatedAt,
  });

  factory AdminSongFile.fromStorageObject(FileObject object, String bucket) {
    final nameWithoutExtension = object.name.replaceAll(
      RegExp(r'\.[^.]+$'),
      '',
    );
    var artist = 'Unknown';
    var title = nameWithoutExtension;

    if (nameWithoutExtension.contains(' - ')) {
      final parts = nameWithoutExtension.split(' - ');
      artist = parts.first.trim();
      title = parts.skip(1).join(' - ').trim();
    }

    return AdminSongFile(
      name: object.name,
      bucket: bucket,
      artist: artist,
      title: title,
      updatedAt: object.updatedAt != null
          ? DateTime.tryParse(object.updatedAt!)
          : null,
    );
  }
}

class AdminStorageService {
  const AdminStorageService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static String _sanitizeFileName(String input) {
    const map = {
      'а': 'a',
      'б': 'b',
      'в': 'v',
      'г': 'g',
      'д': 'd',
      'е': 'e',
      'ё': 'yo',
      'ж': 'zh',
      'з': 'z',
      'и': 'i',
      'й': 'y',
      'к': 'k',
      'л': 'l',
      'м': 'm',
      'н': 'n',
      'о': 'o',
      'п': 'p',
      'р': 'r',
      'с': 's',
      'т': 't',
      'у': 'u',
      'ф': 'f',
      'х': 'kh',
      'ц': 'ts',
      'ч': 'ch',
      'ш': 'sh',
      'щ': 'shch',
      'ъ': '',
      'ы': 'y',
      'ь': '',
      'э': 'e',
      'ю': 'yu',
      'я': 'ya',
      'А': 'A',
      'Б': 'B',
      'В': 'V',
      'Г': 'G',
      'Д': 'D',
      'Е': 'E',
      'Ё': 'Yo',
      'Ж': 'Zh',
      'З': 'Z',
      'И': 'I',
      'Й': 'Y',
      'К': 'K',
      'Л': 'L',
      'М': 'M',
      'Н': 'N',
      'О': 'O',
      'П': 'P',
      'Р': 'R',
      'С': 'S',
      'Т': 'T',
      'У': 'U',
      'Ф': 'F',
      'Х': 'Kh',
      'Ц': 'Ts',
      'Ч': 'Ch',
      'Ш': 'Sh',
      'Щ': 'Shch',
      'Ъ': '',
      'Ы': 'Y',
      'Ь': '',
      'Э': 'E',
      'Ю': 'Yu',
      'Я': 'Ya',
      'қ': 'q',
      'Қ': 'Q',
      'ң': 'ng',
      'Ң': 'Ng',
      'ү': 'u',
      'Ү': 'U',
      'ұ': 'u',
      'Ұ': 'U',
      'һ': 'h',
      'Һ': 'H',
      'ә': 'a',
      'Ә': 'A',
      'і': 'i',
      'І': 'I',
      'ө': 'o',
      'Ө': 'O',
    };

    final buffer = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      buffer.write(map[char] ?? char);
    }

    return buffer.toString().replaceAll(RegExp(r'[^\w\s\-.]'), '').trim();
  }

  static Future<List<AdminSongFile>> listSongs(String bucket) async {
    try {
      final files = await _client.storage
          .from(bucket)
          .list(path: '', searchOptions: const SearchOptions(limit: 1000));

      return files
          .where((file) => file.name.isNotEmpty && !file.name.startsWith('.'))
          .map((file) => AdminSongFile.fromStorageObject(file, bucket))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<AdminSongFile>> listAllSongs() async {
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
      await _client.storage
          .from(bucket)
          .uploadBinary(
            fileName,
            fileBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      // Save song metadata to the matching DB table
      final audioUrl = _client.storage.from(bucket).getPublicUrl(fileName);
      if (bucket == 'featured') {
        await _client.from('featured_songs').insert({
          'title': title,
          'artist': artist,
          'storage_path': fileName,
          'category': 'recent',
        });
      } else {
        await _client.from('songs').insert({
          'title': title,
          'artist': artist,
          'audio_url': audioUrl,
          'uploaded_by': _client.auth.currentUser?.id,
        });
      }

      return true;
    } catch (e) {
      print('AdminStorageService.uploadSong error: $e');
      return false;
    }
  }

  static Future<bool> uploadCover({
    required String songFileName,
    required Uint8List bytes,
    required String extension,
  }) async {
    final baseName = _sanitizeFileName(
      songFileName.replaceAll(RegExp(r'\.[^.]+$'), ''),
    );
    final coverName = '$baseName.$extension';

    try {
      await _client.storage
          .from('covers')
          .uploadBinary(
            coverName,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final coverUrl = _client.storage.from('covers').getPublicUrl(coverName);
      // Update cover in featured_songs (album_art_url, matched by storage_path)
      await _client
          .from('featured_songs')
          .update({'album_art_url': coverUrl})
          .eq('storage_path', songFileName);
      // Update cover in songs (cover_url, matched by audio_url containing fileName)
      await _client
          .from('songs')
          .update({'cover_url': coverUrl})
          .ilike('audio_url', '%$songFileName');

      return true;
    } catch (e) {
      print('AdminStorageService.uploadCover error: $e');
      return false;
    }
  }

  static Future<bool> deleteSong(String bucket, String fileName) async {
    try {
      await _client.storage.from(bucket).remove([fileName]);

      // Remove from the matching DB table
      if (bucket == 'featured') {
        await _client
            .from('featured_songs')
            .delete()
            .eq('storage_path', fileName);
      } else {
        await _client
            .from('songs')
            .delete()
            .ilike('audio_url', '%$fileName');
      }

      return true;
    } catch (e) {
      print('AdminStorageService.deleteSong error: $e');
      return false;
    }
  }

  static Future<bool> moveSong({
    required String fileName,
    required String fromBucket,
    required String toBucket,
  }) async {
    try {
      final bytes = await _client.storage.from(fromBucket).download(fileName);
      await _client.storage
          .from(toBucket)
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      await _client.storage.from(fromBucket).remove([fileName]);

      // Sync DB tables: remove from source, insert into target
      final nameWithoutExt = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
      String artist = 'Unknown';
      String title = nameWithoutExt;
      if (nameWithoutExt.contains(' - ')) {
        final parts = nameWithoutExt.split(' - ');
        artist = parts.first.trim();
        title = parts.skip(1).join(' - ').trim();
      }

      final newAudioUrl = _client.storage.from(toBucket).getPublicUrl(fileName);

      // Delete from source table
      if (fromBucket == 'featured') {
        await _client
            .from('featured_songs')
            .delete()
            .eq('storage_path', fileName);
      } else {
        await _client
            .from('songs')
            .delete()
            .ilike('audio_url', '%$fileName');
      }

      // Insert into target table
      if (toBucket == 'featured') {
        await _client.from('featured_songs').insert({
          'title': title,
          'artist': artist,
          'storage_path': fileName,
          'category': 'recent',
        });
      } else {
        await _client.from('songs').insert({
          'title': title,
          'artist': artist,
          'audio_url': newAudioUrl,
          'uploaded_by': _client.auth.currentUser?.id,
        });
      }

      return true;
    } catch (e) {
      print('AdminStorageService.moveSong error: $e');
      return false;
    }
  }

  static Future<Map<String, int>> getStats() async {
    var songsCount = 0;
    var featuredCount = 0;
    var usersCount = 0;
    var playlistsCount = 0;

    try {
      final songs = await _client.storage
          .from('songs')
          .list(searchOptions: const SearchOptions(limit: 1000));
      songsCount = songs
          .where((file) => file.name.isNotEmpty && !file.name.startsWith('.'))
          .length;
    } catch (_) {}

    try {
      final featured = await _client.storage
          .from('featured')
          .list(searchOptions: const SearchOptions(limit: 1000));
      featuredCount = featured
          .where((file) => file.name.isNotEmpty && !file.name.startsWith('.'))
          .length;
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
