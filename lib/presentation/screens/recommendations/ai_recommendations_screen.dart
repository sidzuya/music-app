import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/recommendation_mix_model.dart';
import '../../providers/locale_provider.dart';
import '../../providers/music_provider.dart';
import '../../providers/recommendation_provider.dart';
import '../../widgets/song_tile.dart';

class AiRecommendationsScreen extends StatelessWidget {
  const AiRecommendationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<LocaleProvider, RecommendationProvider>(
      builder: (context, localeProvider, recommendationProvider, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(localeProvider.getString('ai_mixes')),
            actions: [
              IconButton(
                icon: const Icon(Icons.auto_awesome),
                onPressed: () {
                  recommendationProvider.refreshRecommendations(force: true);
                },
              ),
            ],
          ),
          body:
              recommendationProvider.isLoading &&
                  !recommendationProvider.hasMixes
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => recommendationProvider
                      .refreshRecommendations(force: true),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        localeProvider.getString('personalized_for_you'),
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        localeProvider.getString('ai_mixes_description'),
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (!recommendationProvider.hasMixes)
                        _buildEmptyState(localeProvider)
                      else
                        ...recommendationProvider.dailyMixes.map(
                          (mix) => Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: _MixSection(mix: mix),
                          ),
                        ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildEmptyState(LocaleProvider localeProvider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.auto_awesome,
            color: AppTheme.primaryGreen,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            localeProvider.getString('start_listening_for_ai'),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            localeProvider.getString('ai_empty_state'),
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MixSection extends StatelessWidget {
  final RecommendationMixModel mix;

  const _MixSection({required this.mix});

  @override
  Widget build(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 92,
                  height: 92,
                  child: mix.coverImage != null
                      ? Image.network(
                          mix.coverImage!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _MixPlaceholder(title: mix.title);
                          },
                        )
                      : _MixPlaceholder(title: mix.title),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mix.title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      mix.subtitle,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      mix.description,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              musicProvider.playPlaylist(mix.songs, 0);
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Play Mix'),
          ),
          const SizedBox(height: 12),
          ...mix.songs
              .take(5)
              .map(
                (song) => SongTile(
                  song: song,
                  onTap: () {
                    musicProvider.playSong(song);
                  },
                ),
              ),
        ],
      ),
    );
  }
}

class _MixPlaceholder extends StatelessWidget {
  final String title;

  const _MixPlaceholder({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF31C96E), Color(0xFF188F46)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
