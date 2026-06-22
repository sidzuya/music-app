import '../models/social_user_model.dart';

class FriendActivityModel {
  final SocialUser user;
  final String? songTitle;
  final String? songArtist;
  final String? songAlbumArt;
  final String? songUrl;
  final bool isPlaying;
  final bool isOnline;
  final DateTime updatedAt;

  FriendActivityModel({
    required this.user,
    this.songTitle,
    this.songArtist,
    this.songAlbumArt,
    this.songUrl,
    required this.isPlaying,
    this.isOnline = false,
    required this.updatedAt,
  });

  factory FriendActivityModel.fromMap(Map<String, dynamic> map, Map<String, dynamic> profileMap) {
    return FriendActivityModel(
      user: SocialUser.fromMap(profileMap),
      songTitle: map['song_title'] as String?,
      songArtist: map['song_artist'] as String?,
      songAlbumArt: map['song_album_art'] as String?,
      songUrl: map['song_url'] as String?,
      isPlaying: (map['is_playing'] as bool?) ?? false,
      isOnline: (map['is_online'] as bool?) ?? false,
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at'] as String) 
          : DateTime.now(),
    );
  }
}
