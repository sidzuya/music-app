/// Model for artist analytics summary
class ArtistAnalyticsSummary {
  final int totalListens;
  final int totalUniqueListeners;
  final int totalTracks;
  final double avgListensPerTrack;

  ArtistAnalyticsSummary({
    required this.totalListens,
    required this.totalUniqueListeners,
    required this.totalTracks,
    required this.avgListensPerTrack,
  });

  factory ArtistAnalyticsSummary.fromMap(Map<String, dynamic> map) {
    return ArtistAnalyticsSummary(
      totalListens: (map['total_listens'] as num?)?.toInt() ?? 0,
      totalUniqueListeners: (map['total_unique_listeners'] as num?)?.toInt() ?? 0,
      totalTracks: (map['total_tracks'] as num?)?.toInt() ?? 0,
      avgListensPerTrack: (map['avg_listens_per_track'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Model for daily track statistics
class DailyTrackStat {
  final DateTime date;
  final int listensCount;
  final int uniqueListeners;

  DailyTrackStat({
    required this.date,
    required this.listensCount,
    required this.uniqueListeners,
  });

  factory DailyTrackStat.fromMap(Map<String, dynamic> map) {
    return DailyTrackStat(
      date: DateTime.parse(map['stat_date'] as String),
      listensCount: (map['listens_count'] as num?)?.toInt() ?? 0,
      uniqueListeners: (map['unique_listeners'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Model for top track
class TopTrack {
  final String trackId;
  final String title;
  final int listensCount;
  final int uniqueListeners;

  TopTrack({
    required this.trackId,
    required this.title,
    required this.listensCount,
    required this.uniqueListeners,
  });

  factory TopTrack.fromMap(Map<String, dynamic> map) {
    return TopTrack(
      trackId: map['track_id'] as String,
      title: map['track_title'] as String,
      listensCount: (map['listens_count'] as num?)?.toInt() ?? 0,
      uniqueListeners: (map['unique_listeners'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Model for country statistics
class CountryStat {
  final String country;
  final int listensCount;

  CountryStat({
    required this.country,
    required this.listensCount,
  });

  factory CountryStat.fromMap(Map<String, dynamic> map) {
    return CountryStat(
      country: map['country'] as String? ?? 'Unknown',
      listensCount: (map['listens_count'] as num?)?.toInt() ?? 0,
    );
  }
}
