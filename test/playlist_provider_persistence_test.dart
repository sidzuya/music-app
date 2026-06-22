import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/data/models/song_model.dart';
import 'package:music_app/data/services/playlist_remote_writer.dart';
import 'package:music_app/presentation/providers/playlist_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

SongModel _song(String title, String artist) => SongModel(
      title: title,
      artist: artist,
      album: 'Album',
      duration: const Duration(seconds: 180),
      genre: 'rock',
      createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
      audioUrl: 'https://example.com/$title.mp3',
    );

class _FakeRemoteWriter implements PlaylistRemoteWriter {
  bool createShouldReturnNull = false;
  Exception? createShouldThrow;
  final List<String> createdPlaylistIds = [];
  final List<String> createdNames = [];
  final List<(String, SongModel)> addedSongs = [];

  @override
  Future<String?> createPlaylist(String name, String? description) async {
    createdNames.add(name);
    if (createShouldThrow != null) throw createShouldThrow!;
    if (createShouldReturnNull) return null;
    final id = 'uuid-${createdPlaylistIds.length + 1}';
    createdPlaylistIds.add(id);
    return id;
  }

  @override
  Future<bool> addSongToPlaylist(String playlistId, SongModel song) async {
    addedSongs.add((playlistId, song));
    return true;
  }

  @override
  Future<bool> addToFavorites(SongModel song) async => true;
  @override
  Future<bool> removeFromFavorites(SongModel song) async => true;
  @override
  Future<List<SongModel>> getFavorites() async => const [];
  @override
  Future<List<Map<String, dynamic>>> getPlaylists() async => [];

  @override
  Future<List<SongModel>> getPlaylistSongs(String playlistId) async => [];

  @override
  Future<bool> deletePlaylist(String playlistId) async => true;
  @override
  Future<bool> updatePlaylist(
    String playlistId,
    String name,
    String? description,
  ) async =>
      true;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PlaylistProvider ↔ Supabase writer contract', () {
    test(
      'saves playlist + songs to remote when Supabase insert succeeds',
      () async {
        final writer = _FakeRemoteWriter();
        final provider = PlaylistProvider(
          remoteWriter: writer,
          autoLoad: false,
        );

        final playlist = await provider.createPlaylist('My AI Mix', 'desc');

        expect(playlist, isNotNull);
        expect(writer.createdNames, ['My AI Mix']);
        expect(writer.createdPlaylistIds, hasLength(1));

        final ok = await provider.addSongToPlaylist(
          playlist!.id!,
          _song('Track A', 'Artist'),
        );
        expect(ok, isTrue);
        expect(writer.addedSongs, hasLength(1));
        expect(writer.addedSongs.single.$1, writer.createdPlaylistIds.single);
        expect(writer.addedSongs.single.$2.title, 'Track A');
      },
    );

    test(
      'surfaces Supabase failure as null instead of silently creating local-only playlist',
      () async {
        final writer = _FakeRemoteWriter()..createShouldReturnNull = true;
        final provider = PlaylistProvider(
          remoteWriter: writer,
          autoLoad: false,
        );

        final playlist = await provider.createPlaylist('Bad Mix', null);

        expect(
          playlist,
          isNull,
          reason:
              'When Supabase rejects the insert, the provider must surface the '
              'failure so the UI can warn the user instead of pretending the '
              'playlist was saved.',
        );
        expect(provider.playlists, isEmpty);
      },
    );

    test(
      'surfaces Supabase exception as null (defensive, no throw escapes provider)',
      () async {
        final writer = _FakeRemoteWriter()
          ..createShouldThrow = Exception('RLS policy denies insert');
        final provider = PlaylistProvider(
          remoteWriter: writer,
          autoLoad: false,
        );

        final playlist = await provider.createPlaylist('Bad Mix', null);
        expect(playlist, isNull);
        expect(provider.playlists, isEmpty);
      },
    );

    test(
      'useSupabase=false creates local-only playlist without touching the writer',
      () async {
        final writer = _FakeRemoteWriter();
        final provider = PlaylistProvider(
          remoteWriter: writer,
          useSupabase: false,
          autoLoad: false,
        );

        final playlist = await provider.createPlaylist('Local', null);

        expect(playlist, isNotNull);
        expect(writer.createdNames, isEmpty);
        expect(writer.createdPlaylistIds, isEmpty);
        expect(provider.playlists, hasLength(1));
      },
    );
  });
}
