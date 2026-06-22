import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/data/models/social_user_model.dart';

/// Regression tests for the bug where followers / following / friends lists
/// rendered empty (while the counts still showed 2/2/2).
///
/// Root cause: the `profiles` SELECT statements named the optional
/// `social_links` column explicitly. When that column is missing from the live
/// database (the `artist_profile_update.sql` migration was not applied), the
/// PostgREST query fails and the catch-block returns an empty list — so the
/// lists looked empty even though the `follows` rows (and therefore the counts)
/// existed.
///
/// The fix selects all existing columns instead of naming `social_links`, so a
/// missing column is simply absent. These tests lock in the contract that a
/// profile row WITHOUT `social_links` still maps into a fully-visible user, so
/// it is never dropped from a list.
void main() {
  group('Profile row resilience (social_links column absent)', () {
    test('SocialUser.fromMap on a row without social_links yields a visible user', () {
      final user = SocialUser.fromMap({
        'id': 'user-1',
        'username': 'friend_one',
        'email': 'friend1@example.com',
        'profile_image': null,
      });

      expect(user.id, 'user-1');
      expect(user.username, 'friend_one');
      // Defaults must keep the user visible so it is never filtered out.
      expect(user.profileVisible, true);
      expect(user.followersVisible, true);
      expect(user.playlistsVisible, true);
    });

    test('Mapping a batch of rows without social_links keeps every user '
        '(mirrors FollowService._profilesByIds)', () {
      final rows = <Map<String, dynamic>>[
        {'id': 'a', 'username': 'alpha', 'email': 'a@x.com'},
        {'id': 'b', 'username': 'beta', 'email': 'b@x.com'},
      ];

      final users = rows.map(SocialUser.fromMap).toList();

      expect(users.length, 2);
      expect(users.map((u) => u.id), containsAll(<String>['a', 'b']));
    });

    test('searchUsers-style filter keeps users that lack social_links', () {
      const myId = 'me';
      final rows = <Map<String, dynamic>>[
        {'id': 'me', 'username': 'self', 'email': 'me@x.com'},
        {'id': 'other', 'username': 'other', 'email': 'o@x.com'},
        {'id': '', 'username': 'broken'},
      ];

      final results = rows
          .map(SocialUser.fromMap)
          .where((u) => u.id.isNotEmpty && u.id != myId && u.profileVisible)
          .toList();

      expect(results.length, 1);
      expect(results.single.id, 'other');
    });

    test('Privacy settings are still honoured when social_links IS present', () {
      final hidden = SocialUser.fromMap({
        'id': 'x',
        'username': 'private_user',
        'social_links': [
          {'type': 'privacy_settings', 'followers_visible': false},
        ],
      });

      expect(hidden.followersVisible, false);
      expect(hidden.profileVisible, true);
    });
  });
}
