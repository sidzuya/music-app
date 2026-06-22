import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/report_model.dart';

class ReportsService {
  ReportsService._();

  static SupabaseClient get _client => Supabase.instance.client;

  /// Submit a new report. Anyone authenticated may submit.
  static Future<void> submit({
    required ReportTargetType targetType,
    required String targetId,
    required String reason,
    String? details,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Не авторизован');
    await _client.from('reports').insert({
      'reporter_id': user.id,
      'target_type': reportTargetTypeToString(targetType),
      'target_id': targetId,
      'reason': reason.trim(),
      'details': details?.trim(),
      'status': 'open',
    });
  }

  /// Moderator queue: open reports first.
  static Future<List<ReportItem>> queue({
    ReportStatus status = ReportStatus.open,
    int limit = 100,
  }) async {
    final rows = await _client
        .from('reports')
        .select()
        .eq('status', status.name)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((r) => ReportItem.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Moderator resolves or dismisses a report.
  static Future<void> setStatus(
    String reportId,
    ReportStatus status, {
    String? note,
  }) async {
    final user = _client.auth.currentUser;
    await _client.from('reports').update({
      'status': status.name,
      'reviewer_id': user?.id,
      'reviewer_note': note,
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', reportId);
  }
}
