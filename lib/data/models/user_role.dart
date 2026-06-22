/// All roles supported by the backend (`profiles.role`).
enum UserRole {
  user,
  artist,
  moderator,
  admin;

  static UserRole fromString(String? raw) {
    switch (raw) {
      case 'admin':
        return UserRole.admin;
      case 'moderator':
        return UserRole.moderator;
      case 'artist':
        return UserRole.artist;
      default:
        return UserRole.user;
    }
  }

  String get value => name;

  bool get isAdmin => this == UserRole.admin;
  bool get isModerator => this == UserRole.moderator || this == UserRole.admin;
  bool get isArtist => this == UserRole.artist || this == UserRole.admin;
  bool get canUploadSongs => isArtist;
  bool get canReviewApplications => isModerator;
  bool get canManageRoles => isAdmin;

  String get label {
    switch (this) {
      case UserRole.user:
        return 'Пользователь';
      case UserRole.artist:
        return 'Исполнитель';
      case UserRole.moderator:
        return 'Модератор';
      case UserRole.admin:
        return 'Администратор';
    }
  }
}
