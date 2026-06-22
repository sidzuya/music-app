import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user_model.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart';
import '../../core/constants/app_constants.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, AppConstants.databaseName);

    return await openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE ${AppConstants.usersTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT UNIQUE NOT NULL,
        username TEXT NOT NULL,
        profile_image TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Songs table
    await db.execute('''
      CREATE TABLE ${AppConstants.songsTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        artist TEXT NOT NULL,
        album TEXT NOT NULL,
        album_art TEXT,
        audio_url TEXT,
        duration_seconds INTEGER NOT NULL,
        genre TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_favorite INTEGER DEFAULT 0
      )
    ''');

    // Playlists table
    await db.execute('''
      CREATE TABLE ${AppConstants.playlistsTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        cover_image TEXT,
        user_id INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES ${AppConstants.usersTable} (id) ON DELETE CASCADE
      )
    ''');

    // Playlist songs junction table
    await db.execute('''
      CREATE TABLE ${AppConstants.playlistSongsTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        playlist_id INTEGER NOT NULL,
        song_id INTEGER NOT NULL,
        position INTEGER NOT NULL,
        added_at TEXT NOT NULL,
        FOREIGN KEY (playlist_id) REFERENCES ${AppConstants.playlistsTable} (id) ON DELETE CASCADE,
        FOREIGN KEY (song_id) REFERENCES ${AppConstants.songsTable} (id) ON DELETE CASCADE,
        UNIQUE(playlist_id, song_id)
      )
    ''');

    // Favorites table
    await db.execute('''
      CREATE TABLE ${AppConstants.favoritesTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        song_id INTEGER NOT NULL,
        added_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES ${AppConstants.usersTable} (id) ON DELETE CASCADE,
        FOREIGN KEY (song_id) REFERENCES ${AppConstants.songsTable} (id) ON DELETE CASCADE,
        UNIQUE(user_id, song_id)
      )
    ''');

    // Insert sample data
    await _insertSampleData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades here
  }

  Future<void> _insertSampleData(Database db) async {
    // Insert sample songs
    final sampleSongs = [
      {
        'title': 'Blinding Lights',
        'artist': 'The Weeknd',
        'album': 'After Hours',
        'duration_seconds': 200,
        'genre': 'Pop',
        'created_at': DateTime.now().toIso8601String(),
      },
      {
        'title': 'Watermelon Sugar',
        'artist': 'Harry Styles',
        'album': 'Fine Line',
        'duration_seconds': 174,
        'genre': 'Pop',
        'created_at': DateTime.now().toIso8601String(),
      },
      {
        'title': 'Levitating',
        'artist': 'Dua Lipa',
        'album': 'Future Nostalgia',
        'duration_seconds': 203,
        'genre': 'Pop',
        'created_at': DateTime.now().toIso8601String(),
      },
      {
        'title': 'Good 4 U',
        'artist': 'Olivia Rodrigo',
        'album': 'SOUR',
        'duration_seconds': 178,
        'genre': 'Pop Rock',
        'created_at': DateTime.now().toIso8601String(),
      },
      {
        'title': 'Stay',
        'artist': 'The Kid LAROI & Justin Bieber',
        'album': 'F*CK LOVE 3: OVER YOU',
        'duration_seconds': 141,
        'genre': 'Pop',
        'created_at': DateTime.now().toIso8601String(),
      },
    ];

    for (final song in sampleSongs) {
      await db.insert(AppConstants.songsTable, song);
    }
  }

  // User operations
  Future<int> insertUser(UserModel user) async {
    final db = await database;
    return await db.insert(AppConstants.usersTable, user.toMap());
  }

  Future<UserModel?> getUserByEmail(String email) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.usersTable,
      where: 'email = ?',
      whereArgs: [email],
    );

    if (maps.isNotEmpty) {
      return UserModel.fromMap(maps.first);
    }
    return null;
  }

  Future<UserModel?> getUserById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.usersTable,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return UserModel.fromMap(maps.first);
    }
    return null;
  }

  // Song operations
  Future<List<SongModel>> getAllSongs() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(AppConstants.songsTable);
    return List.generate(maps.length, (i) => SongModel.fromMap(maps[i]));
  }

  Future<List<SongModel>> searchSongs(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.songsTable,
      where: 'title LIKE ? OR artist LIKE ? OR album LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
    );
    return List.generate(maps.length, (i) => SongModel.fromMap(maps[i]));
  }

  Future<int> insertSong(SongModel song) async {
    final db = await database;
    return await db.insert(AppConstants.songsTable, song.toMap());
  }

  // Playlist operations
  Future<int> insertPlaylist(PlaylistModel playlist) async {
    final db = await database;
    return await db.insert(AppConstants.playlistsTable, playlist.toMap());
  }

  Future<List<PlaylistModel>> getUserPlaylists(int userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.playlistsTable,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return List.generate(maps.length, (i) => PlaylistModel.fromMap(maps[i]));
  }

  Future<void> addSongToPlaylist(int playlistId, int songId) async {
    final db = await database;
    
    // Get the current max position
    final List<Map<String, dynamic>> positionMaps = await db.query(
      AppConstants.playlistSongsTable,
      columns: ['MAX(position) as max_position'],
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
    );
    
    final int position = (positionMaps.first['max_position'] ?? -1) + 1;
    
    await db.insert(AppConstants.playlistSongsTable, {
      'playlist_id': playlistId,
      'song_id': songId,
      'position': position,
      'added_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<SongModel>> getPlaylistSongs(int playlistId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT s.* FROM ${AppConstants.songsTable} s
      INNER JOIN ${AppConstants.playlistSongsTable} ps ON s.id = ps.song_id
      WHERE ps.playlist_id = ?
      ORDER BY ps.position
    ''', [playlistId]);
    
    return List.generate(maps.length, (i) => SongModel.fromMap(maps[i]));
  }

  // Favorites operations
  Future<void> toggleFavorite(int userId, int songId) async {
    final db = await database;
    
    final List<Map<String, dynamic>> existing = await db.query(
      AppConstants.favoritesTable,
      where: 'user_id = ? AND song_id = ?',
      whereArgs: [userId, songId],
    );
    
    if (existing.isNotEmpty) {
      // Remove from favorites
      await db.delete(
        AppConstants.favoritesTable,
        where: 'user_id = ? AND song_id = ?',
        whereArgs: [userId, songId],
      );
    } else {
      // Add to favorites
      await db.insert(AppConstants.favoritesTable, {
        'user_id': userId,
        'song_id': songId,
        'added_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<List<SongModel>> getFavoriteSongs(int userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT s.* FROM ${AppConstants.songsTable} s
      INNER JOIN ${AppConstants.favoritesTable} f ON s.id = f.song_id
      WHERE f.user_id = ?
      ORDER BY f.added_at DESC
    ''', [userId]);
    
    return List.generate(maps.length, (i) => SongModel.fromMap(maps[i]));
  }

  Future<bool> isFavorite(int userId, int songId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.favoritesTable,
      where: 'user_id = ? AND song_id = ?',
      whereArgs: [userId, songId],
    );
    return maps.isNotEmpty;
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
