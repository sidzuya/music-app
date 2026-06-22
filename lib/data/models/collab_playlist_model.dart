class CollabPlaylistModel {
  final String id;
  final String playlistId;
  final String userId;
  final String invitedBy;
  final String status; // 'pending' | 'accepted' | 'declined'
  final DateTime createdAt;

  // Optional: populated fields for display
  final String? playlistName;
  final String? invitedByUsername;
  final String? invitedByAvatarUrl;

  CollabPlaylistModel({
    required this.id,
    required this.playlistId,
    required this.userId,
    required this.invitedBy,
    required this.status,
    required this.createdAt,
    this.playlistName,
    this.invitedByUsername,
    this.invitedByAvatarUrl,
  });

  factory CollabPlaylistModel.fromMap(Map<String, dynamic> map) {
    return CollabPlaylistModel(
      id: map['id'] as String,
      playlistId: map['playlist_id'] as String,
      userId: map['user_id'] as String,
      invitedBy: map['invited_by'] as String,
      status: map['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(map['created_at'] as String),
      playlistName: map['playlist_name'] as String?,
      invitedByUsername: map['invited_by_username'] as String?,
      invitedByAvatarUrl: map['invited_by_avatar_url'] as String?,
    );
  }

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isDeclined => status == 'declined';
}
