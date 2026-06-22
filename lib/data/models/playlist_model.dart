class PlaylistModel {
  final int? id;
  final String name;
  final String? description;
  final String? coverImage;
  final int userId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<int> songIds;

  PlaylistModel({
    this.id,
    required this.name,
    this.description,
    this.coverImage,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    this.songIds = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'cover_image': coverImage,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PlaylistModel.fromMap(Map<String, dynamic> map) {
    return PlaylistModel(
      id: map['id']?.toInt(),
      name: map['name'] ?? '',
      description: map['description'],
      coverImage: map['cover_image'],
      userId: map['user_id']?.toInt() ?? 0,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      songIds: [], // Will be populated separately
    );
  }

  PlaylistModel copyWith({
    int? id,
    String? name,
    String? description,
    String? coverImage,
    int? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<int>? songIds,
  }) {
    return PlaylistModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      coverImage: coverImage ?? this.coverImage,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      songIds: songIds ?? this.songIds,
    );
  }

  @override
  String toString() {
    return 'PlaylistModel(id: $id, name: $name, description: $description, userId: $userId, songCount: ${songIds.length})';
  }
}
