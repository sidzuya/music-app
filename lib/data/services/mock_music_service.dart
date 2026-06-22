import '../models/song_model.dart';
import '../models/playlist_model.dart';

class MockMusicService {
  static final MockMusicService _instance = MockMusicService._internal();
  factory MockMusicService() => _instance;
  MockMusicService._internal();

  // Моковые данные песен
  final List<SongModel> _songs = [
    SongModel(
      id: 1,
      title: 'Blinding Lights',
      artist: 'The Weeknd',
      album: 'After Hours',
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      duration: const Duration(minutes: 3, seconds: 20),
      genre: 'Pop',
      createdAt: DateTime.now(),
      albumArt:
          'https://i.scdn.co/image/ab67616d0000b273c06f0e8b33d2e8c0c8b5e5e5',
    ),
    SongModel(
      id: 2,
      title: 'Watermelon Sugar',
      artist: 'Harry Styles',
      album: 'Fine Line',
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
      duration: const Duration(minutes: 2, seconds: 54),
      genre: 'Pop',
      createdAt: DateTime.now(),
      albumArt:
          'https://i.scdn.co/image/ab67616d0000b273adaeba4c8e8c0c8b5e5e5e5e',
    ),
    SongModel(
      id: 3,
      title: 'Levitating',
      artist: 'Dua Lipa',
      album: 'Future Nostalgia',
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
      duration: const Duration(minutes: 3, seconds: 23),
      genre: 'Pop',
      createdAt: DateTime.now(),
      albumArt:
          'https://i.scdn.co/image/ab67616d0000b273be841ba4bc4aebfeacb5e5e5',
    ),
    SongModel(
      id: 4,
      title: 'Good 4 U',
      artist: 'Olivia Rodrigo',
      album: 'SOUR',
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
      duration: const Duration(minutes: 2, seconds: 58),
      genre: 'Pop Rock',
      createdAt: DateTime.now(),
      albumArt:
          'https://i.scdn.co/image/ab67616d0000b273a91c10fe9472d9bd89802e5e',
    ),
    SongModel(
      id: 5,
      title: 'Stay',
      artist: 'The Kid LAROI & Justin Bieber',
      album: 'F*CK LOVE 3: OVER YOU',
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',
      duration: const Duration(minutes: 2, seconds: 21),
      genre: 'Pop',
      createdAt: DateTime.now(),
      albumArt:
          'https://i.scdn.co/image/ab67616d0000b273fc915b69600dce2991ec8042',
    ),
    SongModel(
      id: 6,
      title: 'As It Was',
      artist: 'Harry Styles',
      album: 'Harry\'s House',
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3',
      duration: const Duration(minutes: 2, seconds: 47),
      genre: 'Pop',
      createdAt: DateTime.now(),
    ),
    SongModel(
      id: 7,
      title: 'Heat Waves',
      artist: 'Glass Animals',
      album: 'Dreamland',
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-7.mp3',
      duration: const Duration(minutes: 3, seconds: 58),
      genre: 'Indie Pop',
      createdAt: DateTime.now(),
    ),
    SongModel(
      id: 8,
      title: 'Anti-Hero',
      artist: 'Taylor Swift',
      album: 'Midnights',
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3',
      duration: const Duration(minutes: 3, seconds: 20),
      genre: 'Pop',
      createdAt: DateTime.now(),
    ),
    SongModel(
      id: 9,
      title: 'Shape of You',
      artist: 'Ed Sheeran',
      album: 'Divide',
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-9.mp3',
      duration: const Duration(minutes: 3, seconds: 53),
      genre: 'Pop',
      createdAt: DateTime.now(),
    ),
    SongModel(
      id: 10,
      title: 'Starboy',
      artist: 'The Weeknd',
      album: 'Starboy',
      audioUrl:
          'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-10.mp3',
      duration: const Duration(minutes: 3, seconds: 50),
      genre: 'Pop',
      createdAt: DateTime.now(),
    ),
    SongModel(
      id: 11,
      title: 'Numb',
      artist: 'Linkin Park',
      album: 'Meteora',
      audioUrl:
          'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-11.mp3',
      duration: const Duration(minutes: 3, seconds: 7),
      genre: 'Rock',
      createdAt: DateTime.now(),
    ),
    SongModel(
      id: 12,
      title: 'Lose Yourself',
      artist: 'Eminem',
      album: '8 Mile',
      audioUrl:
          'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-12.mp3',
      duration: const Duration(minutes: 5, seconds: 26),
      genre: 'Hip-Hop',
      createdAt: DateTime.now(),
    ),
    SongModel(
      id: 13,
      title: 'Believer',
      artist: 'Imagine Dragons',
      album: 'Evolve',
      audioUrl:
          'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-13.mp3',
      duration: const Duration(minutes: 3, seconds: 24),
      genre: 'Alternative Rock',
      createdAt: DateTime.now(),
    ),
    SongModel(
      id: 14,
      title: 'Sunflower',
      artist: 'Post Malone & Swae Lee',
      album: 'Spider-Man: Into the Spider-Verse',
      audioUrl:
          'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-14.mp3',
      duration: const Duration(minutes: 2, seconds: 38),
      genre: 'Hip-Hop',
      createdAt: DateTime.now(),
    ),
    SongModel(
      id: 15,
      title: 'bad guy',
      artist: 'Billie Eilish',
      album: 'WHEN WE ALL FALL ASLEEP, WHERE DO WE GO?',
      audioUrl:
          'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-15.mp3',
      duration: const Duration(minutes: 3, seconds: 14),
      genre: 'Pop',
      createdAt: DateTime.now(),
    ),
    SongModel(
      id: 16,
      title: 'Someone You Loved',
      artist: 'Lewis Capaldi',
      album: 'Divinely Uninspired to a Hellish Extent',
      audioUrl:
          'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-16.mp3',
      duration: const Duration(minutes: 3, seconds: 2),
      genre: 'Pop',
      createdAt: DateTime.now(),
    ),
    SongModel(
      id: 17,
      title: 'Smells Like Teen Spirit',
      artist: 'Nirvana',
      album: 'Nevermind',
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      duration: const Duration(minutes: 5, seconds: 1),
      genre: 'Rock',
      createdAt: DateTime.now(),
    ),
    SongModel(
      id: 18,
      title: 'Seven Nation Army',
      artist: 'The White Stripes',
      album: 'Elephant',
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
      duration: const Duration(minutes: 3, seconds: 51),
      genre: 'Rock',
      createdAt: DateTime.now(),
    ),
  ];

  final List<PlaylistModel> _playlists = [];
  final Set<int> _favoriteSongs = {};

  // Получить все песни
  Future<List<SongModel>> getAllSongs() async {
    await Future.delayed(
      const Duration(milliseconds: 300),
    ); // Имитация загрузки
    return List.from(_songs);
  }

  // Поиск песен
  Future<List<SongModel>> searchSongs(String query) async {
    await Future.delayed(const Duration(milliseconds: 200));

    if (query.isEmpty) return [];

    final lowercaseQuery = query.toLowerCase();
    return _songs.where((song) {
      return song.title.toLowerCase().contains(lowercaseQuery) ||
          song.artist.toLowerCase().contains(lowercaseQuery) ||
          song.album.toLowerCase().contains(lowercaseQuery) ||
          song.genre.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  // Получить песню по ID
  Future<SongModel?> getSongById(int id) async {
    return _songs.where((song) => song.id == id).firstOrNull;
  }

  // Получить популярные песни
  Future<List<SongModel>> getPopularSongs({int limit = 10}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _songs.take(limit).toList();
  }

  // Получить недавно проигранные песни (мок)
  Future<List<SongModel>> getRecentlyPlayed({int limit = 10}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _songs.reversed.take(limit).toList();
  }

  // Получить песни по жанру
  Future<List<SongModel>> getSongsByGenre(String genre) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _songs
        .where((song) => song.genre.toLowerCase().contains(genre.toLowerCase()))
        .toList();
  }

  // Плейлисты
  Future<List<PlaylistModel>> getUserPlaylists(int userId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _playlists.where((playlist) => playlist.userId == userId).toList();
  }

  Future<int> createPlaylist(PlaylistModel playlist) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final newPlaylist = playlist.copyWith(
      id: _playlists.length + 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _playlists.add(newPlaylist);
    return newPlaylist.id!;
  }

  Future<List<SongModel>> getPlaylistSongs(int playlistId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final playlist = _playlists.where((p) => p.id == playlistId).firstOrNull;
    if (playlist == null) return [];

    return _songs.where((song) => playlist.songIds.contains(song.id)).toList();
  }

  // Избранные песни
  Future<void> toggleFavorite(int userId, int songId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (_favoriteSongs.contains(songId)) {
      _favoriteSongs.remove(songId);
    } else {
      _favoriteSongs.add(songId);
    }
  }

  Future<List<SongModel>> getFavoriteSongs(int userId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _songs.where((song) => _favoriteSongs.contains(song.id)).toList();
  }

  Future<bool> isFavorite(int userId, int songId) async {
    return _favoriteSongs.contains(songId);
  }

  // Получить рекомендации
  Future<List<SongModel>> getRecommendations({int limit = 5}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final shuffled = List<SongModel>.from(_songs)..shuffle();
    return shuffled.take(limit).toList();
  }
}

extension FirstWhereOrNullExtension<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
