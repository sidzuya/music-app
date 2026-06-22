import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/artist_analytics_model.dart';
import '../../../data/services/artist_analytics_service.dart';

/// Analytics dashboard for artists
class ArtistAnalyticsScreen extends StatefulWidget {
  final String artistId;

  const ArtistAnalyticsScreen({
    required this.artistId,
    super.key,
  });

  @override
  State<ArtistAnalyticsScreen> createState() => _ArtistAnalyticsScreenState();
}

class _ArtistAnalyticsScreenState extends State<ArtistAnalyticsScreen> {
  late Future<ArtistAnalyticsSummary> _summaryFuture;
  late Future<List<TopTrack>> _topTracksFuture;
  late Future<List<CountryStat>> _countryFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _summaryFuture = ArtistAnalyticsService.getArtistSummary(widget.artistId);
    _topTracksFuture = ArtistAnalyticsService.getTopTracks(widget.artistId);
    _countryFuture = ArtistAnalyticsService.getCountryDistribution(widget.artistId);
  }

  Future<void> _refresh() async {
    setState(_loadData);
    await _summaryFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text('Аналитика'),
        backgroundColor: AppTheme.darkBackground,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary cards
              _buildSummaryCards(),
              const SizedBox(height: 24),

              // Top tracks section
              const Text(
                'Топ треки',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildTopTracks(),
              const SizedBox(height: 24),

              // Country distribution
              const Text(
                'География слушателей',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildCountryStats(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return FutureBuilder<ArtistAnalyticsSummary>(
      future: _summaryFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Text('Ошибка: ${snap.error}');
        }

        final summary = snap.data;
        if (summary == null) {
          return const Text('Нет данных');
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Всего прослушиваний',
                    value: summary.totalListens.toString(),
                    icon: Icons.play_circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    title: 'Уникальные слушатели',
                    value: summary.totalUniqueListeners.toString(),
                    icon: Icons.people,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Всего треков',
                    value: summary.totalTracks.toString(),
                    icon: Icons.music_note,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    title: 'Среднее слушаний/трек',
                    value: summary.avgListensPerTrack.toStringAsFixed(0),
                    icon: Icons.trending_up,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      color: const Color.fromARGB(255, 28, 28, 30),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.primaryGreen, size: 20),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopTracks() {
    return FutureBuilder<List<TopTrack>>(
      future: _topTracksFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Text('Ошибка: ${snap.error}');
        }

        final tracks = snap.data ?? [];
        if (tracks.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('Нет данных')),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tracks.length,
          itemBuilder: (context, index) {
            final track = tracks[index];
            return Card(
              color: const Color.fromARGB(255, 28, 28, 30),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                title: Text(track.title),
                subtitle: Text(
                  '${track.listensCount} слушаний • ${track.uniqueListeners} слушателей',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${track.listensCount}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    const Text(
                      'plays',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCountryStats() {
    return FutureBuilder<List<CountryStat>>(
      future: _countryFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Text('Ошибка: ${snap.error}');
        }

        final countries = snap.data ?? [];
        if (countries.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('Нет данных')),
          );
        }

        // Get max listens for bar scaling
        final maxListens = countries.isNotEmpty
            ? countries.map((c) => c.listensCount).reduce((a, b) => a > b ? a : b)
            : 0;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: countries.length,
          itemBuilder: (context, index) {
            final country = countries[index];
            final percentage =
                maxListens > 0 ? (country.listensCount / maxListens) : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        country.country,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '${country.listensCount}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 8,
                      color: Colors.grey.withOpacity(0.2),
                      child: FractionallySizedBox(
                        widthFactor: percentage,
                        child: Container(
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
