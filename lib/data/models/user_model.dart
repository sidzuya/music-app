class UserModel {
  final int? id;
  final String email;
  final String username;
  final String? profileImage;
  final String? bannerImage;
  final String? bio;
  final List<Map<String, dynamic>>? socialLinks;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    this.id,
    required this.email,
    required this.username,
    this.profileImage,
    this.bannerImage,
    this.bio,
    this.socialLinks,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get profileVisible {
    if (socialLinks == null) return true;
    for (final link in socialLinks!) {
      if (link['type'] == 'privacy_settings') {
        return link['profile_visible'] ?? true;
      }
    }
    return true;
  }

  bool get playlistsVisible {
    if (socialLinks == null) return true;
    for (final link in socialLinks!) {
      if (link['type'] == 'privacy_settings') {
        return link['playlists_visible'] ?? true;
      }
    }
    return true;
  }

  bool get followersVisible {
    if (socialLinks == null) return true;
    for (final link in socialLinks!) {
      if (link['type'] == 'privacy_settings') {
        return link['followers_visible'] ?? true;
      }
    }
    return true;
  }

  bool get listeningActivity {
    if (socialLinks == null) return false;
    for (final link in socialLinks!) {
      if (link['type'] == 'privacy_settings') {
        return link['listening_activity'] ?? false;
      }
    }
    return false;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'profile_image': profileImage,
      'banner_image': bannerImage,
      'bio': bio,
      'social_links': socialLinks,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id']?.toInt(),
      email: map['email'] ?? '',
      username: map['username'] ?? '',
      profileImage: map['profile_image'],
      bannerImage: map['banner_image'],
      bio: map['bio'],
      socialLinks: map['social_links'] != null
          ? List<Map<String, dynamic>>.from(map['social_links'])
          : null,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  UserModel copyWith({
    int? id,
    String? email,
    String? username,
    String? profileImage,
    String? bannerImage,
    String? bio,
    List<Map<String, dynamic>>? socialLinks,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      profileImage: profileImage ?? this.profileImage,
      bannerImage: bannerImage ?? this.bannerImage,
      bio: bio ?? this.bio,
      socialLinks: socialLinks ?? this.socialLinks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, email: $email, username: $username, profileImage: $profileImage, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}
