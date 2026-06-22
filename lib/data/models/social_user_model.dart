import 'dart:convert';

/// Lightweight projection of a Supabase `profiles` row used by the social
/// graph (followers / following / friends / search).
class SocialUser {
  /// Supabase auth user id (uuid string).
  final String id;
  final String username;
  final String? email;
  final String? profileImage;
  final bool profileVisible;
  final bool playlistsVisible;
  final bool followersVisible;
  final bool listeningActivity;
  final String? bio;
  final List<Map<String, dynamic>>? socialLinks;

  const SocialUser({
    required this.id,
    required this.username,
    this.email,
    this.profileImage,
    this.profileVisible = true,
    this.playlistsVisible = true,
    this.followersVisible = true,
    this.listeningActivity = false,
    this.bio,
    this.socialLinks,
  });

  factory SocialUser.fromMap(Map<String, dynamic> map) {
    final socialLinksRaw = map['social_links'];
    List<dynamic> socialLinks = [];
    if (socialLinksRaw is List) {
      socialLinks = socialLinksRaw;
    } else if (socialLinksRaw is String) {
      try {
        socialLinks = jsonDecode(socialLinksRaw) as List;
      } catch (_) {}
    }
    
    Map<String, dynamic>? privacyEntry;
    for (var link in socialLinks) {
      if (link is Map && link['type'] == 'privacy_settings') {
        privacyEntry = Map<String, dynamic>.from(link);
        break;
      }
    }

    final actualLinks = socialLinks
        .where((link) => link is Map && link['type'] != 'privacy_settings')
        .map((link) => Map<String, dynamic>.from(link as Map))
        .toList();

    return SocialUser(
      id: (map['id'] as String?) ?? '',
      username: (map['username'] as String?) ??
          (map['email'] as String?)?.split('@').first ??
          'User',
      email: map['email'] as String?,
      profileImage: map['profile_image'] as String?,
      profileVisible: privacyEntry?['profile_visible'] ?? true,
      playlistsVisible: privacyEntry?['playlists_visible'] ?? true,
      followersVisible: privacyEntry?['followers_visible'] ?? true,
      listeningActivity: privacyEntry?['listening_activity'] ?? false,
      bio: map['bio'] as String?,
      socialLinks: actualLinks,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is SocialUser && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
