enum ReportTargetType { song, playlist, profile, comment }

ReportTargetType _typeFromString(String raw) {
  switch (raw) {
    case 'playlist':
      return ReportTargetType.playlist;
    case 'profile':
      return ReportTargetType.profile;
    case 'comment':
      return ReportTargetType.comment;
    default:
      return ReportTargetType.song;
  }
}

String reportTargetTypeToString(ReportTargetType t) {
  switch (t) {
    case ReportTargetType.song:
      return 'song';
    case ReportTargetType.playlist:
      return 'playlist';
    case ReportTargetType.profile:
      return 'profile';
    case ReportTargetType.comment:
      return 'comment';
  }
}

enum ReportStatus { open, resolved, dismissed }

ReportStatus _statusFromString(String raw) {
  switch (raw) {
    case 'resolved':
      return ReportStatus.resolved;
    case 'dismissed':
      return ReportStatus.dismissed;
    default:
      return ReportStatus.open;
  }
}

class ReportItem {
  final String id;
  final String reporterId;
  final ReportTargetType targetType;
  final String targetId;
  final String reason;
  final String? details;
  final ReportStatus status;
  final String? reviewerId;
  final String? reviewerNote;
  final DateTime createdAt;
  final DateTime? reviewedAt;

  const ReportItem({
    required this.id,
    required this.reporterId,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.details,
    this.reviewerId,
    this.reviewerNote,
    this.reviewedAt,
  });

  factory ReportItem.fromMap(Map<String, dynamic> map) {
    return ReportItem(
      id: map['id'] as String,
      reporterId: map['reporter_id'] as String,
      targetType: _typeFromString(map['target_type'] as String),
      targetId: map['target_id'].toString(),
      reason: (map['reason'] ?? '') as String,
      details: map['details'] as String?,
      status: _statusFromString(map['status'] as String? ?? 'open'),
      reviewerId: map['reviewer_id'] as String?,
      reviewerNote: map['reviewer_note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      reviewedAt: map['reviewed_at'] != null
          ? DateTime.parse(map['reviewed_at'] as String)
          : null,
    );
  }
}
