import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/search_results.dart';
import '../../../data/models/song_model.dart';
import '../../../data/services/follow_service.dart';
import '../../../data/services/hybrid_music_service.dart';
import '../../../data/services/search_aggregator.dart';
import '../../../data/services/supabase_database_service.dart';
import '../../providers/music_provider.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/song_tile.dart';
import '../../widgets/user_tile.dart';
import '../artist/artist_profile_screen.dart';
import 'playlist_results_screen.dart';

class SearchScreen extends StatefulWidget {
  final SearchAggregator? aggregator;
  const SearchScreen({super.key, this.aggregator});

  @override
  State<SearchScreen> createState() => SearchScreenState();
}

class SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final HybridMusicService _musicService = HybridMusicService();
  final FollowService _followService = FollowService();
  final SupabaseDatabaseService _dbService = SupabaseDatabaseService();
  late final SearchAggregator _aggregator = widget.aggregator ?? SearchAggregator(
    searchSongs: (q) => _musicService.searchSongs(q),
    searchPlaylists: (q) async {
      final rows = await _dbService.searchPublicPlaylists(q);
      return rows.map(PlaylistSummary.fromMap).toList();
    },
    searchProfiles: (q) => _followService.searchUsers(q),
  );
  Timer? _searchDebounce;
  SearchResults _results = SearchResults.empty;
  List<SongModel> _discoverSongs = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String _selectedCategory = 'all';

  final List<String> _genres = [
    'Pop',
    'Rock',
    'Hip-Hop',
    'Electronic',
    'Jazz',
    'Classical',
    'Country',
    'R&B',
    'Indie',
    'Alternative',
    'Folk',
    'Blues',
  ];

  final List<Color> _genreColors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.amber,
    Colors.cyan,
    Colors.lime,
    Colors.deepOrange,
  ];

  @override
  void initState() {
    super.initState();
    _loadDiscoverSongs();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Returns the screen to its initial browse state: clears the query,
  /// dismisses any genre/search results and unfocuses the input.
  void resetToBrowse() {
    _searchDebounce?.cancel();
    _searchController.clear();
    if (mounted) {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() {
        _results = SearchResults.empty;
        _hasSearched = false;
        _isLoading = false;
        _selectedCategory = 'all';
      });
    }
  }

  Future<void> _loadDiscoverSongs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final songs = await _musicService.getPopularSongs(limit: 12);

      setState(() {
        _discoverSongs = songs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handleSearchChanged(String query) {
    _searchDebounce?.cancel();

    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      setState(() {
        _results = SearchResults.empty;
        _hasSearched = false;
      });
      return;
    }

    _searchDebounce = Timer(
      const Duration(milliseconds: 400),
      () => _performSearch(trimmedQuery),
    );
  }

  Future<void> _performSearch(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      setState(() {
        _results = SearchResults.empty;
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final results = await _aggregator.search(trimmedQuery);
      if (!mounted) return;
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _results = SearchResults.empty;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadGenreSongs(String genre) async {
    _searchDebounce?.cancel();
    _searchController.text = genre;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final results = await _musicService.getSongsByGenre(genre, limit: 24);
      if (!mounted) return;
      setState(() {
        _results = SearchResults(
          songs: results,
          artists: SearchAggregator.deriveArtistsForUi(results, genre),
        );
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _results = SearchResults.empty;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: Column(
              children: [
                // Search Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localeProvider.getString('search'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Search Bar
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: localeProvider.getString(
                              'search_placeholder',
                            ),
                            hintStyle: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodySmall?.color,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onChanged: _handleSearchChanged,
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    if (_hasSearched) {
      return Column(
        children: [
          _buildFilterChips(),
          Expanded(child: _buildSearchResults()),
        ],
      );
    }

    return _buildBrowseContent();
  }

  Widget _buildFilterChips() {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
        final categories = [
          {'id': 'all', 'label': 'Все'},
          {
            'id': 'songs',
            'label': localeProvider.getString('section_songs') == 'section_songs'
                ? 'Треки'
                : localeProvider.getString('section_songs'),
          },
          {
            'id': 'artists',
            'label': localeProvider.getString('section_artists') == 'section_artists'
                ? 'Исполнители'
                : localeProvider.getString('section_artists'),
          },
          {
            'id': 'playlists',
            'label': localeProvider.getString('section_playlists') == 'section_playlists'
                ? 'Плейлисты'
                : localeProvider.getString('section_playlists'),
          },
          {
            'id': 'profiles',
            'label': localeProvider.getString('section_profiles') == 'section_profiles'
                ? 'Профили'
                : localeProvider.getString('section_profiles'),
          },
        ];

        return Container(
          height: 48,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = _selectedCategory == cat['id'];

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    cat['label']!,
                    style: TextStyle(
                      color: isSelected ? Colors.black : AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: Theme.of(context).colorScheme.primary,
                  backgroundColor: AppTheme.cardBackground,
                  checkmarkColor: Colors.black,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedCategory = cat['id']!;
                      });
                    }
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSearchResults() {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
        final showAll = _selectedCategory == 'all';
        final showProfiles = (_selectedCategory == 'profiles' || showAll) && _results.profiles.isNotEmpty;
        final showArtists = (_selectedCategory == 'artists' || showAll) && _results.artists.isNotEmpty;
        final showPlaylists = (_selectedCategory == 'playlists' || showAll) && _results.playlists.isNotEmpty;
        final showSongs = (_selectedCategory == 'songs' || showAll) && _results.songs.isNotEmpty;

        final hasAnyMatch = showAll 
            ? !_results.isEmpty
            : ((_selectedCategory == 'profiles' && _results.profiles.isNotEmpty) ||
               (_selectedCategory == 'artists' && _results.artists.isNotEmpty) ||
               (_selectedCategory == 'playlists' && _results.playlists.isNotEmpty) ||
               (_selectedCategory == 'songs' && _results.songs.isNotEmpty));

        if (!hasAnyMatch) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.search_off,
                  size: 64,
                  color: AppTheme.textTertiary,
                ),
                const SizedBox(height: 16),
                Text(
                  localeProvider.getString('no_results'),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  localeProvider.getString('try_different_search'),
                  style: const TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            if (showProfiles && _selectedCategory == 'profiles') ...[
              _sectionTitle(localeProvider.getString('section_profiles')),
              ..._results.profiles.map(
                (user) => UserTile(user: user),
              ),
            ] else if (showAll && _results.profiles.isNotEmpty) ...[
              _sectionTitle(localeProvider.getString('section_profiles')),
              ..._results.profiles.map(
                (user) => UserTile(user: user),
              ),
              const SizedBox(height: 16),
            ],

            if (showArtists && _selectedCategory == 'artists') ...[
              _sectionTitle(localeProvider.getString('section_artists')),
              ..._results.artists.map(_buildArtistTile),
            ] else if (showAll && _results.artists.isNotEmpty) ...[
              _sectionTitle(localeProvider.getString('section_artists')),
              ..._results.artists.map(_buildArtistTile),
              const SizedBox(height: 16),
            ],

            if (showPlaylists && _selectedCategory == 'playlists') ...[
              _sectionTitle(localeProvider.getString('section_playlists')),
              ..._results.playlists.map(_buildPlaylistTile),
            ] else if (showAll && _results.playlists.isNotEmpty) ...[
              _sectionTitle(localeProvider.getString('section_playlists')),
              ..._results.playlists.map(_buildPlaylistTile),
              const SizedBox(height: 16),
            ],

            if (showSongs && _selectedCategory == 'songs') ...[
              _sectionTitle(localeProvider.getString('section_songs')),
              ..._results.songs.map(
                (s) => SongTile(
                  song: s,
                  onTap: () {
                    Provider.of<MusicProvider>(
                      context,
                      listen: false,
                    ).playPlaylist(_results.songs, _results.songs.indexOf(s));
                  },
                ),
              ),
            ] else if (showAll && _results.songs.isNotEmpty) ...[
              _sectionTitle(localeProvider.getString('section_songs')),
              ..._results.songs.map(
                (s) => SongTile(
                  song: s,
                  onTap: () {
                    Provider.of<MusicProvider>(
                      context,
                      listen: false,
                    ).playPlaylist(_results.songs, _results.songs.indexOf(s));
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }


  Widget _buildArtistTile(String artist) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primary.withValues(
              alpha: 0.2,
            ),
        child: Icon(
          Icons.mic,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Text(
        artist,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ArtistProfileScreen(
              artistId: '',
              artistName: artist,
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaylistTile(PlaylistSummary playlist) {
    final cover = playlist.coverUrl;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 48,
          height: 48,
          child: cover != null && cover.isNotEmpty
              ? Image.network(cover, fit: BoxFit.cover)
              : Container(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.2),
                  child: Icon(
                    Icons.queue_music,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
        ),
      ),
      title: Text(
        playlist.name,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: playlist.ownerUsername != null
          ? Text(
              '@${playlist.ownerUsername!}',
              style: const TextStyle(color: AppTheme.textSecondary),
            )
          : null,
      trailing: const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlaylistResultsScreen(playlist: playlist),
          ),
        );
      },
    );
  }

  Widget _buildBrowseContent() {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Browse All Section
              Text(
                localeProvider.getString('browse_all'),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Genre Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _genres.length,
                itemBuilder: (context, index) {
                  return _buildGenreCard(
                    _genres[index],
                    _genreColors[index % _genreColors.length],
                  );
                },
              ),
              const SizedBox(height: 32),

              if (_discoverSongs.isNotEmpty) ...[
                Text(
                  localeProvider.getString('popular_right_now'),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _discoverSongs.length,
                  itemBuilder: (context, index) {
                    final song = _discoverSongs[index];
                    return SongTile(
                      song: song,
                      onTap: () {
                        Provider.of<MusicProvider>(
                          context,
                          listen: false,
                        ).playPlaylist(_discoverSongs, index);
                      },
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],

              // Recently Searched (if any)
              if (_hasSearched) ...[
                Text(
                  'Recent Searches', // This could be localized too if needed
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Add recent searches here
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildGenreCard(String genre, Color color) {
    return GestureDetector(
      onTap: () {
        _loadGenreSongs(genre);
      },
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              bottom: -10,
              child: Transform.rotate(
                angle: 0.3,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  genre,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
