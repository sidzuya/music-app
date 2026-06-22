import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/artist_analytics_model.dart';

/// Service for artist analytics
class ArtistAnalyticsService {
  ArtistAnalyticsService._();

  static SupabaseClient get _client => Supabase.instance.client;

  /// Get artist summary (total listens, unique listeners, etc.)
  static Future<ArtistAnalyticsSummary> getArtistSummary(String artistId) async {
    try {
      final result = await _client.rpc(
        'get_artist_summary',
        params: {'p_artist_id': artistId},
      );

      final data = result is PostgrestResponse ? result.data : result;
      if (data is List && data.isNotEmpty) {
        return ArtistAnalyticsSummary.fromMap(
          Map<String, dynamic>.from(data.first as Map),
        );
      }
      if (data is Map<String, dynamic>) {
        return ArtistAnalyticsSummary.fromMap(data);
      }
      throw Exception('Unexpected response type for artist summary: ${data.runtimeType}');
    } catch (e) {
      throw Exception('Error fetching artist summary: $e');
    }
  }

  /// Get daily stats for a specific track
  static Future<List<DailyTrackStat>> getTrackDailyStats(
    String trackId, {
    int days = 30,
  }) async {
    try {
      final result = await _client.rpc(
        'get_track_daily_stats',
        params: {'p_track_id': trackId, 'p_days': days},
      );
      final data = result is PostgrestResponse ? result.data : result;
      if (data is List) {
        return data
            .map((stat) => DailyTrackStat.fromMap(Map<String, dynamic>.from(stat as Map)))
            .toList();
      }
      throw Exception('Unexpected response type for track daily stats: ${data.runtimeType}');
    } catch (e) {
      throw Exception('Error fetching daily stats: $e');
    }
  }

  /// Get top tracks for an artist
  static Future<List<TopTrack>> getTopTracks(
    String artistId, {
    int limit = 10,
  }) async {
    try {
      final result = await _client.rpc(
        'get_artist_top_tracks',
        params: {'p_artist_id': artistId, 'p_limit': limit},
      );
      final data = result is PostgrestResponse ? result.data : result;
      if (data is List) {
        return data
            .map((track) => TopTrack.fromMap(Map<String, dynamic>.from(track as Map)))
            .toList();
      }
      throw Exception('Unexpected response type for top tracks: ${data.runtimeType}');
    } catch (e) {
      throw Exception('Error fetching top tracks: $e');
    }
  }

  /// Get country distribution for an artist (or specific track)
  static Future<List<CountryStat>> getCountryDistribution(
    String artistId, {
    String? trackId,
  }) async {
    try {
      final result = await _client.rpc(
        'get_artist_country_distribution',
        params: {
          'p_artist_id': artistId,
          'p_track_id': trackId,
        },
      );
      final data = result is PostgrestResponse ? result.data : result;
      if (data is List) {
        return data
            .map((country) => CountryStat.fromMap(Map<String, dynamic>.from(country as Map)))
            .toList();
      }
      throw Exception('Unexpected response type for country distribution: ${data.runtimeType}');
    } catch (e) {
      throw Exception('Error fetching country distribution: $e');
    }
  }

  /// Record a track listen
  static Future<void> recordListen(
    String trackId, {
    String? userId,
    int? durationSeconds,
    String? deviceType,
    String? country,
  }) async {
    try {
      await _client.rpc(
        'record_track_listen',
        params: {
          'p_track_id': trackId,
          'p_user_id': userId ?? _client.auth.currentUser?.id,
          'p_duration_seconds': durationSeconds,
          'p_device_type': deviceType,
          'p_country': country,
        },
      );
    } catch (e) {
      // Don't throw error if listen recording fails, it's not critical
      print('Warning: Failed to record listen: $e');
    }
  }
}
