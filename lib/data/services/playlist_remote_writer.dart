import '../models/song_model.dart';

/// Abstraction over the remote persistence layer used by [PlaylistProvider].
///
/// Keeps the provider decoupled from [SupabaseDatabaseService] so it can be
/// tested without a live Supabase connection. The concrete implementation
/// (`SupabaseDatabaseService`) `implements` this contract.
abstract class PlaylistRemoteWriter {
  Future<List<SongModel>> getFavorites();
  Future<bool> addToFavorites(SongModel song);
  Future<bool> removeFromFavorites(SongModel song);

  Future<List<Map<String, dynamic>>> getPlaylists();
  Future<String?> createPlaylist(String name, String? description);
  Future<bool> deletePlaylist(String playlistId);
  Future<bool> updatePlaylist(
    String playlistId,
    String name,
    String? description,
  );

  Future<bool> addSongToPlaylist(String playlistId, SongModel song);
  Future<List<SongModel>> getPlaylistSongs(String playlistId);
}
