enum ArtistApplicationStatus { pending, approved, rejected }

ArtistApplicationStatus _statusFromString(String? raw) {
  switch (raw) {
    case 'approved':
      return ArtistApplicationStatus.approved;
    case 'rejected':
      return ArtistApplicationStatus.rejected;
    default:
      return ArtistApplicationStatus.pending;
  }
}

class ArtistApplication {
  final String id;
  final String userId;
  final String artistName;
  final String? bio;
  final String? links;
  final String reason;
  final ArtistApplicationStatus status;
  final String? reviewerId;
  final String? reviewerNote;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  // Optional joined fields (when querying with profile join).
  final String? userEmail;
  final String? username;

  const ArtistApplication({
    required this.id,
    required this.userId,
    required this.artistName,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.bio,
    this.links,
    this.reviewerId,
    this.reviewerNote,
    this.reviewedAt,
    this.userEmail,
    this.username,
  });

  factory ArtistApplication.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    return ArtistApplication(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      artistName: (map['artist_name'] ?? '') as String,
      bio: map['bio'] as String?,
      links: map['links'] as String?,
      reason: (map['reason'] ?? '') as String,
      status: _statusFromString(map['status'] as String?),
      reviewerId: map['reviewer_id'] as String?,
      reviewerNote: map['reviewer_note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      reviewedAt: map['reviewed_at'] != null
          ? DateTime.parse(map['reviewed_at'] as String)
          : null,
      userEmail: profile?['email'] as String? ?? map['email'] as String?,
      username: profile?['username'] as String? ?? map['username'] as String?,
    );
  }

  String get statusLabel {
    switch (status) {
      case ArtistApplicationStatus.pending:
        return 'На рассмотрении';
      case ArtistApplicationStatus.approved:
        return 'Одобрено';
      case ArtistApplicationStatus.rejected:
        return 'Отклонено';
    }
  }
}
