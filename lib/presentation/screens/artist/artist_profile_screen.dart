import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/songs_catalog_service.dart';
import '../../../data/models/song_model.dart';
import '../../../data/services/hybrid_music_service.dart';
import '../../providers/music_provider.dart';
import '../../widgets/song_tile.dart';

class ArtistProfileScreen extends StatefulWidget {
  final String artistId;
  final String artistName;

  const ArtistProfileScreen({super.key, required this.artistId, required this.artistName});

  @override
  State<ArtistProfileScreen> createState() => _ArtistProfileScreenState();
}

class _ArtistProfileScreenState extends State<ArtistProfileScreen> {
  UserModel? _artistProfile;
  List<SongModel> _artistSongs = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    await Future.wait([
      _loadArtistProfile(),
      _loadArtistSongs(),
    ]);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadArtistProfile() async {
    try {
      final query = Supabase.instance.client.from('profiles').select();
      final response = await (widget.artistId.isNotEmpty 
          ? query.eq('id', widget.artistId).maybeSingle()
          : query.ilike('username', widget.artistName).maybeSingle());

      if (response != null) {
        if (mounted) {
          setState(() {
            _artistProfile = UserModel.fromMap(response);
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to load artist profile: $e');
    }
  }

  Future<void> _loadArtistSongs() async {
    try {
      final hybridService = HybridMusicService();
      final externalSongs = await hybridService.searchSongs(widget.artistName, limit: 50);
      
      final matchingSongs = externalSongs.where((s) => s.artist.toLowerCase().contains(widget.artistName.toLowerCase())).toList();

      List<SongModel> internalSongs = [];
      if (widget.artistId.isNotEmpty) {
        final catalogSongs = await SongsCatalogService.fetchSongsByArtistId(widget.artistId);
        internalSongs = catalogSongs.map((e) => e.toSongModel()).toList();
      }

      final allSongs = [...internalSongs, ...matchingSongs];
      
      final uniqueSongs = <String, SongModel>{};
      for (final song in allSongs) {
        final key = '${song.title.toLowerCase()}_${song.artist.toLowerCase()}';
        if (!uniqueSongs.containsKey(key)) {
          uniqueSongs[key] = song;
        }
      }

      if (mounted) {
        setState(() {
          _artistSongs = uniqueSongs.values.toList();
        });
      }
    } catch (e) {
      debugPrint('Failed to load artist songs: $e');
    }
  }

  List<Map<String, String>> get _albums {
    final albums = <String, Map<String, String>>{};
    for (final song in _artistSongs) {
      if (song.album.isNotEmpty && song.album != 'Supabase' && song.album != 'Apple Music Preview') {
        if (!albums.containsKey(song.album)) {
          albums[song.album] = {
            'title': song.album,
            'coverUrl': song.albumArt ?? '',
          };
        }
      }
    }
    return albums.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      expandedHeight: 250.0,
                      floating: false,
                      pinned: true,
                      flexibleSpace: FlexibleSpaceBar(
                        background: _buildBannerImage(),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildListDelegate(
                        [
                          _buildArtistHeader(context),
                          _buildArtistBio(context),
                          _buildSocialLinks(context),
                          _buildAlbumsSection(context),
                          _buildArtistSongs(context),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildBannerImage() {
    final bannerUrl = _artistProfile?.bannerImage;
    if (bannerUrl != null && bannerUrl.isNotEmpty) {
      return Image.network(
        bannerUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: AppTheme.cardBackground,
          child: const Icon(Icons.broken_image, color: AppTheme.textTertiary),
        ),
      );
    }
    
    if (_artistSongs.isNotEmpty && _artistSongs.first.albumArt != null) {
      return Image.network(
        _artistSongs.first.albumArt!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: AppTheme.cardBackground,
        ),
      );
    }
    
    return Container(
      color: AppTheme.cardBackground,
      child: Center(child: Icon(Icons.music_note, color: Theme.of(context).colorScheme.primary, size: 50)),
    );
  }

  Widget _buildArtistHeader(BuildContext context) {
    String avatarUrl = _artistProfile?.profileImage ?? '';
    if (avatarUrl.isEmpty && _artistSongs.isNotEmpty && _artistSongs.first.albumArt != null) {
      avatarUrl = _artistSongs.first.albumArt!;
    }
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Theme.of(context).colorScheme.primary,
                backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl.isEmpty
                    ? Text(
                        (widget.artistName.isNotEmpty ? widget.artistName[0] : 'A').toUpperCase(),
                        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.black),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _artistProfile?.username ?? widget.artistName,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildArtistBio(BuildContext context) {
    final bio = _artistProfile?.bio;
    if (bio != null && bio.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Text(
          bio,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16),
        ),
      );
    }
    
    if (_artistProfile == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Text(
          'Информация о ${widget.artistName} получена из открытых источников.',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildSocialLinks(BuildContext context) {
    final socialLinks = _artistProfile?.socialLinks;
    if (socialLinks != null && socialLinks.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Wrap(
          spacing: 12.0,
          runSpacing: 8.0,
          children: socialLinks.map((link) => _buildSocialLinkItem(context, link)).toList(),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildSocialLinkItem(BuildContext context, Map<String, dynamic> link) {
    final platform = link['platform'] ?? 'Website';
    final url = link['url'];

    if (url == null || url.isEmpty) return const SizedBox.shrink();

    IconData icon;
    switch (platform.toString().toLowerCase()) {
      case 'instagram':
        icon = Icons.camera_alt;
        break;
      case 'facebook':
        icon = Icons.facebook;
        break;
      case 'twitter':
        icon = Icons.discord;
        break;
      case 'youtube':
        icon = Icons.play_arrow;
        break;
      default:
        icon = Icons.link;
    }

    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch $url')),
          );
        }
      },
      child: Chip(
        label: Text(platform),
        avatar: Icon(icon),
        backgroundColor: AppTheme.cardBackground,
        labelStyle: const TextStyle(color: AppTheme.textPrimary),
      ),
    );
  }

  Widget _buildAlbumsSection(BuildContext context) {
    final albums = _albums;
    if (albums.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Альбомы и релизы',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: albums.length,
              itemBuilder: (context, index) {
                final album = albums[index];
                return Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: album['coverUrl']!.isNotEmpty
                            ? Image.network(
                                album['coverUrl']!,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 120,
                                height: 120,
                                color: AppTheme.cardBackground,
                                child: const Icon(Icons.album, size: 40, color: AppTheme.textSecondary),
                              ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        album['title']!,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistSongs(BuildContext context) {
    if (_artistSongs.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Популярные треки',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _artistSongs.length,
            itemBuilder: (context, index) {
              final song = _artistSongs[index];
              return SongTile(
                song: song,
                onTap: () {
                  Provider.of<MusicProvider>(context, listen: false).playPlaylist(_artistSongs, index);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
