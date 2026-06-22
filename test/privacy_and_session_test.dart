import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:music_app/core/theme/app_theme.dart';
import 'package:music_app/data/models/user_model.dart';
import 'package:music_app/data/models/social_user_model.dart';
import 'package:music_app/data/models/search_results.dart';
import 'package:music_app/data/models/song_model.dart';
import 'package:music_app/data/models/collab_playlist_model.dart';
import 'package:music_app/data/services/session_service.dart';
import 'package:music_app/data/services/follow_service.dart';
import 'package:music_app/data/services/notification_service.dart';
import 'package:music_app/data/services/supabase_database_service.dart';
import 'package:music_app/presentation/providers/auth_provider.dart';
import 'package:music_app/presentation/providers/locale_provider.dart';
import 'package:music_app/presentation/providers/follow_provider.dart';
import 'package:music_app/presentation/providers/notification_provider.dart';
import 'package:music_app/presentation/providers/collab_playlist_provider.dart';
import 'package:music_app/presentation/screens/settings/account_settings_screen.dart';
import 'package:music_app/presentation/screens/settings/notifications_settings_screen.dart';
import 'package:music_app/presentation/screens/home/notifications_screen.dart';
import 'package:music_app/presentation/widgets/notification_overlay.dart';
import 'package:music_app/presentation/screens/social/public_profile_screen.dart';
import 'package:music_app/presentation/screens/social/follow_list_screen.dart';
import 'package:music_app/presentation/screens/search/playlist_results_screen.dart';

class FakeLocaleProvider extends ChangeNotifier implements LocaleProvider {
  @override
  String getString(String key) {
    switch (key) {
      case 'privacy':
        return 'Конфиденциальность';
      case 'public_profile':
        return 'Публичный профиль';
      case 'public_playlists':
        return 'Публичные плейлисты';
      case 'show_followers':
        return 'Показывать подписчиков';
      case 'listening_activity':
        return 'Активность прослушивания';
      case 'active_sessions':
        return 'Активные сессии';
      case 'login_history':
        return 'История входов';
      case 'playlists':
        return 'Плейлисты';
      case 'playlists_hidden_by_settings':
        return 'Этот список скрыт настройками';
      case 'followers':
        return 'Подписчики';
      case 'following':
        return 'Подписки';
      case 'friends':
        return 'Друзья';
      default:
        return key;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  UserModel? _currentUser = UserModel(
    id: 1,
    email: 'test@example.com',
    username: 'testuser',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    socialLinks: [
      {
        'type': 'privacy_settings',
        'profile_visible': true,
        'playlists_visible': true,
        'followers_visible': true,
        'listening_activity': false,
      }
    ],
  );
  bool _isLoggedIn = true;

  @override
  UserModel? get currentUser => _currentUser;

  @override
  bool get isLoggedIn => _isLoggedIn;

  @override
  Future<void> updateProfile({
    required String username,
    String? bio,
    List<Map<String, dynamic>>? socialLinks,
    dynamic profileImageFile,
    dynamic bannerImageFile,
  }) async {
    _currentUser = _currentUser?.copyWith(
      username: username,
      bio: bio,
      socialLinks: socialLinks,
    );
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFollowProvider extends ChangeNotifier implements FollowProvider {
  @override
  bool isFollowing(String userId) => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSupabaseDatabaseService extends SupabaseDatabaseService {
  final List<Map<String, dynamic>> playlists;
  final List<SongModel> songs;

  FakeSupabaseDatabaseService({
    this.playlists = const [],
    this.songs = const [],
  }) : super.forTesting();

  @override
  Future<List<Map<String, dynamic>>> getUserPlaylists(String userId) async {
    return playlists;
  }

  @override
  Future<List<SongModel>> getPlaylistSongs(String playlistId) async {
    return songs;
  }
}

class FakeFollowService extends FollowService {
  final SocialUser? profile;
  final FollowCounts counts;

  FakeFollowService({
    this.profile,
    this.counts = FollowCounts.empty,
  }) : super.forTesting();

  @override
  Future<SocialUser?> getProfile(String userId) async {
    return profile;
  }

  @override
  Future<FollowCounts> getCounts(String userId) async {
    return counts;
  }

  @override
  Future<Set<String>> followingIds(String userId) async {
    return <String>{};
  }

  @override
  Future<Set<String>> followerIds(String userId) async {
    return <String>{};
  }
}

class MockLocalStorage extends LocalStorage {
  const MockLocalStorage();
  @override
  Future<void> initialize() async {}
  @override
  Future<String?> accessToken() async => null;
  @override
  Future<bool> hasAccessToken() async => false;
  @override
  Future<void> persistSession(String session) async {}
  @override
  Future<void> removePersistedSession() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'https://placeholder-project.supabase.co',
        anonKey: 'placeholderAnonKey',
        authOptions: const FlutterAuthClientOptions(
          localStorage: MockLocalStorage(),
        ),
      );
    } catch (_) {}
  });

  group('Model Privacy Parsing Tests', () {
    test('UserModel and SocialUser extract privacy properties correctly', () {
      final socialLinks = [
        {
          'type': 'privacy_settings',
          'profile_visible': false,
          'playlists_visible': false,
          'followers_visible': false,
          'listening_activity': true,
        }
      ];

      final user = UserModel(
        id: 1,
        email: 'test@example.com',
        username: 'testuser',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        socialLinks: socialLinks,
      );

      expect(user.profileVisible, false);
      expect(user.playlistsVisible, false);
      expect(user.followersVisible, false);
      expect(user.listeningActivity, true);

      final socialUser = SocialUser.fromMap({
        'id': 'abc',
        'username': 'abcuser',
        'email': 'abc@example.com',
        'social_links': socialLinks,
      });

      expect(socialUser.profileVisible, false);
      expect(socialUser.playlistsVisible, false);
      expect(socialUser.followersVisible, false);
      expect(socialUser.listeningActivity, true);
    });

    test('Defaults are applied when privacy entry is absent', () {
      final user = UserModel(
        id: 1,
        email: 'test@example.com',
        username: 'testuser',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(user.profileVisible, true);
      expect(user.playlistsVisible, true);
      expect(user.followersVisible, true);
      expect(user.listeningActivity, false);

      final socialUser = SocialUser.fromMap({
        'id': 'abc',
        'username': 'abcuser',
      });

      expect(socialUser.profileVisible, true);
      expect(socialUser.playlistsVisible, true);
      expect(socialUser.followersVisible, true);
      expect(socialUser.listeningActivity, false);
    });
  });

  group('SessionService and AccountSettingsScreen Active Sessions Tests', () {
    test('SessionService logs and manages sessions in SharedPreferences', () async {
      final service = SessionService.instance;
      final email = 'test@example.com';

      // Initially empty or only contains current session on register
      await service.registerNewSession(email);

      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('login_history_list_${email.toLowerCase()}');
      final sessionsJson = prefs.getString('active_sessions_list_${email.toLowerCase()}');

      expect(historyJson, isNotNull);
      expect(sessionsJson, isNotNull);

      final historyList = jsonDecode(historyJson!) as List;
      final sessionsList = jsonDecode(sessionsJson!) as List;

      expect(historyList.length, 1);
      expect(sessionsList.length, 1);
      expect(sessionsList[0]['isCurrent'], 'true');
    });

    testWidgets('AccountSettingsScreen loads active sessions correctly', (WidgetTester tester) async {
      final email = 'test@example.com';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_sessions_list_${email.toLowerCase()}', jsonEncode([
        {'id': '1', 'device': 'Safari на iPhone', 'lastActive': 'Текущая', 'isCurrent': 'true'},
        {'id': '2', 'device': 'Firefox на Windows', 'lastActive': '1 день назад', 'isCurrent': 'false'},
      ]));

      final authProvider = FakeAuthProvider();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LocaleProvider>.value(value: FakeLocaleProvider()),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: const MaterialApp(home: AccountSettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Open active sessions modal
      final tile = find.text('Активные сессии');
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(find.text('Firefox на Windows'), findsOneWidget);
    });
  });

  group('PublicProfileScreen Privacy Constraint Tests', () {
    Widget createPublicProfileScreen(
      SocialUser targetUser, {
      SupabaseDatabaseService? dbService,
      FollowService? followService,
    }) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<LocaleProvider>.value(value: FakeLocaleProvider()),
          ChangeNotifierProvider<AuthProvider>.value(value: FakeAuthProvider()),
          ChangeNotifierProvider<FollowProvider>.value(value: FakeFollowProvider()),
        ],
        child: MaterialApp(
          home: PublicProfileScreen(
            user: targetUser,
            dbService: dbService,
            followService: followService,
          ),
        ),
      );
    }

    testWidgets('PublicProfileScreen shows playlists even when playlistsVisible is false, but viewing it blocks the songs', (WidgetTester tester) async {
      final targetUser = SocialUser.fromMap({
        'id': 'other-id',
        'username': 'otheruser',
        'email': 'other@example.com',
        'social_links': [
          {
            'type': 'privacy_settings',
            'playlists_visible': false,
          }
        ],
      });

      final fakeDb = FakeSupabaseDatabaseService(
        playlists: [
          {
            'id': 'playlist-id',
            'name': 'Cool Playlist',
            'description': 'Description',
            'cover_url': '',
            'user_id': 'other-id',
            'username': 'otheruser',
          }
        ],
        songs: [
          SongModel(
            id: 1,
            title: 'Test Song',
            artist: 'Test Artist',
            album: 'Test Album',
            audioUrl: 'https://example.com/audio.mp3',
            duration: Duration.zero,
            genre: 'Pop',
            createdAt: DateTime.now(),
          ),
        ],
      );

      final fakeFollow = FakeFollowService(
        profile: targetUser,
      );

      await tester.pumpWidget(
        createPublicProfileScreen(
          targetUser,
          dbService: fakeDb,
          followService: fakeFollow,
        ),
      );
      await tester.pumpAndSettle();

      // The header 'Плейлисты' should STILL be visible.
      expect(find.text('Плейлисты'), findsOneWidget);
      // The playlist title 'Cool Playlist' should STILL be visible.
      expect(find.text('Cool Playlist'), findsOneWidget);
      // The placeholder message should NOT be visible on the profile screen itself.
      expect(find.text('Этот список скрыт настройками'), findsNothing);

      // Now tap on the playlist to "view" it
      await tester.tap(find.text('Cool Playlist'));
      await tester.pumpAndSettle();

      // We should now be in PlaylistResultsScreen, which blocks the songs and shows the message
      expect(find.text('Этот список скрыт настройками'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.text('Test Song'), findsNothing);
    });

    testWidgets('PlaylistResultsScreen blocks songs list when owner has playlistsVisible false', (WidgetTester tester) async {
      final owner = SocialUser.fromMap({
        'id': 'owner-id',
        'username': 'owneruser',
        'email': 'owner@example.com',
        'social_links': [
          {
            'type': 'privacy_settings',
            'playlists_visible': false,
          }
        ],
      });

      final playlist = PlaylistSummary(
        id: 'playlist-id',
        name: 'Private Playlist',
        ownerId: 'owner-id',
        ownerUsername: 'owneruser',
      );

      final mockDb = FakeSupabaseDatabaseService(
        songs: [
          SongModel(
            id: 1,
            title: 'Test Song',
            artist: 'Test Artist',
            album: 'Test Album',
            audioUrl: 'https://example.com/audio.mp3',
            duration: Duration.zero,
            genre: 'Pop',
            createdAt: DateTime.now(),
          ),
        ],
      );

      final mockFollow = FakeFollowService(profile: owner);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LocaleProvider>.value(value: FakeLocaleProvider()),
          ],
          child: MaterialApp(
            home: PlaylistResultsScreen(
              playlist: playlist,
              followService: mockFollow,
              databaseService: mockDb,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Expect to see the block message "Этот список скрыт настройками"
      expect(find.text('Этот список скрыт настройками'), findsOneWidget);
      // Expect to see lock icon
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      // Songs should NOT be visible
      expect(find.text('Test Song'), findsNothing);
    });

    testWidgets('PublicProfileScreen keeps stats counts visible when followersVisible is false', (WidgetTester tester) async {
      // When a user hides their followers list, the COUNTS must remain visible
      // on their public profile. Only opening the list itself should show the
      // "list hidden" placeholder (handled by FollowListScreen).
      final targetUser = SocialUser.fromMap({
        'id': 'other-id',
        'username': 'otheruser',
        'email': 'other@example.com',
        'social_links': [
          {
            'type': 'privacy_settings',
            'followers_visible': false,
          }
        ],
      });

      await tester.pumpWidget(createPublicProfileScreen(targetUser));
      await tester.pumpAndSettle();

      // The stats row labels must still be visible.
      expect(find.text('Подписчики'), findsOneWidget);
      expect(find.text('Подписки'), findsOneWidget);
      expect(find.text('Друзья'), findsOneWidget);
    });

    testWidgets('PublicProfileScreen shows Private Profile placeholder when profileVisible is false', (WidgetTester tester) async {
      final targetUser = SocialUser.fromMap({
        'id': 'other-id',
        'username': 'otheruser',
        'email': 'other@example.com',
        'social_links': [
          {
            'type': 'privacy_settings',
            'profile_visible': false,
          }
        ],
      });

      await tester.pumpWidget(createPublicProfileScreen(targetUser));
      await tester.pumpAndSettle();

      expect(find.textContaining('приватным'), findsOneWidget);
      expect(find.text('Плейлисты'), findsNothing);
      expect(find.text('Подписчики'), findsNothing);
    });
  });

  group('PrivacySettingsScreen Toggles Tests', () {
    testWidgets('Toggling privacy settings updates SharedPreferences and reloads correctly', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final authProvider = FakeAuthProvider();

      Widget buildScreen() {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider<LocaleProvider>.value(value: FakeLocaleProvider()),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: const MaterialApp(
            home: PrivacySettingsScreen(),
          ),
        );
      }

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // Find the first switch (profile visible - default true)
      final profileSwitchFinder = find.byType(Switch).first;
      expect(tester.widget<Switch>(profileSwitchFinder).value, isTrue);

      // Tap the switch to toggle it to false
      await tester.tap(profileSwitchFinder);
      await tester.pumpAndSettle();

      // Check it is updated locally to false
      expect(tester.widget<Switch>(profileSwitchFinder).value, isFalse);

      // Verify that SharedPreferences was updated
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('privacy_profile_visible_test@example.com'), isFalse);

      // Now create a new screen (simulating exit and re-entry)
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // Check that the value is still false
      final newProfileSwitchFinder = find.byType(Switch).first;
      expect(tester.widget<Switch>(newProfileSwitchFinder).value, isFalse);
    });
  });

  group('Notification Settings and Filtering Tests', () {
    testWidgets('NotificationsSettingsScreen loads and saves preferences to SharedPreferences', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      
      final service = FakeNotificationService(
        pushEnabledValue: true,
        playlistsEnabledValue: true,
        socialEnabledValue: false,
      );
      final notifProvider = NotificationProvider(service: service);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LocaleProvider>.value(value: FakeLocaleProvider()),
            ChangeNotifierProvider<AuthProvider>.value(value: FakeAuthProvider()),
            ChangeNotifierProvider<NotificationProvider>.value(value: notifProvider),
          ],
          child: const MaterialApp(
            home: NotificationsSettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify that switches are displayed.
      final switches = find.byType(Switch);
      expect(switches, findsNWidgets(3));

      expect(tester.widget<Switch>(switches.at(0)).value, isTrue);
      expect(tester.widget<Switch>(switches.at(1)).value, isTrue);
      expect(tester.widget<Switch>(switches.at(2)).value, isFalse);

      // Toggle Friend activity switch (index 2)
      await tester.tap(switches.at(2));
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(switches.at(2)).value, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('notif_social_enabled_test@example.com'), isTrue);

      // Disable Push notifications
      await tester.tap(switches.at(0));
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(switches.at(0)).value, isFalse);
      expect(prefs.getBool('notif_push_enabled_test@example.com'), isFalse);
    });

    testWidgets('NotificationService and NotificationsScreen filter notifications based on preferences', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'notif_push_enabled_test@example.com': true,
        'notif_playlists_enabled_test@example.com': false, // block playlist collab invites
        'notif_social_enabled_test@example.com': true,      // allow social new follower notifications
      });

      final mockNotifs = [
        NotificationModel(
          id: '1',
          userId: 'test-user-id',
          type: 'new_follower',
          title: 'Новый подписчик',
          message: '@user2 подписался на вас',
          read: false,
          createdAt: DateTime.now(),
        ),
        NotificationModel(
          id: '2',
          userId: 'test-user-id',
          type: 'collab_invite',
          title: 'Приглашение в плейлист',
          message: 'user3 приглашает вас',
          read: false,
          createdAt: DateTime.now(),
        ),
      ];

      final service = FakeNotificationService(mockNotifications: mockNotifs);
      final notifProvider = NotificationProvider(service: service);
      final collabProvider = FakeCollabPlaylistProvider();

      // Trigger initialization so it reads preferences
      await service.initialize();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LocaleProvider>.value(value: FakeLocaleProvider()),
            ChangeNotifierProvider<AuthProvider>.value(value: FakeAuthProvider()),
            ChangeNotifierProvider<NotificationProvider>.value(value: notifProvider),
            ChangeNotifierProvider<CollabPlaylistProvider>.value(value: collabProvider),
          ],
          child: const MaterialApp(
            home: NotificationsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify that 'new_follower' is displayed, but 'collab_invite' is filtered out
      expect(find.text('@user2 подписался на вас'), findsOneWidget);
      expect(find.text('user3 приглашает вас'), findsNothing);
    });

    testWidgets('Tapping a follower notification fetches profile and navigates', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'notif_push_enabled_test@example.com': true,
        'notif_social_enabled_test@example.com': true,
      });

      final mockNotifs = [
        NotificationModel(
          id: '1',
          userId: 'test-user-id',
          type: 'new_follower',
          title: 'Новый подписчик',
          message: '@user2 подписался на вас',
          read: false,
          createdAt: DateTime.now(),
          data: {'follower_id': 'follower-uuid-123'},
        ),
      ];

      final service = FakeNotificationService(mockNotifications: mockNotifs);
      final notifProvider = NotificationProvider(service: service);
      final collabProvider = FakeCollabPlaylistProvider();

      final fakeProfileUser = SocialUser.fromMap({
        'id': 'follower-uuid-123',
        'username': 'user2',
        'email': 'user2@example.com',
      });

      final originalFollowService = FollowService();
      final fakeFollowService = FakeFollowService(profile: fakeProfileUser);
      FollowService.instance = fakeFollowService;

      await service.initialize();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LocaleProvider>.value(value: FakeLocaleProvider()),
            ChangeNotifierProvider<AuthProvider>.value(value: FakeAuthProvider()),
            ChangeNotifierProvider<FollowProvider>.value(value: FakeFollowProvider()),
            ChangeNotifierProvider<NotificationProvider>.value(value: notifProvider),
            ChangeNotifierProvider<CollabPlaylistProvider>.value(value: collabProvider),
          ],
          child: MaterialApp(
            home: Navigator(
              onGenerateRoute: (settings) {
                return MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on the notification card
      await tester.tap(find.text('@user2 подписался на вас'));
      await tester.pump(); // Start navigation/loading
      // Pump with duration to avoid pumpAndSettle timeout on CircularProgressIndicator
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));

      // Verify that we navigated to PublicProfileScreen for user2
      expect(find.text('user2'), findsNWidgets(2));

      // Restore original FollowService singleton
      FollowService.instance = originalFollowService;
    });

    testWidgets('NotificationOverlay displays in-app alert when push notifications are enabled and approved notification is added', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'notif_push_enabled_test@example.com': true,
      });

      final mockNotif = NotificationModel(
        id: 'approved-app-notif',
        userId: 'test-user-id',
        type: 'artist_application_approved',
        title: 'Заявка одобрена',
        message: 'Поздравляем! Ваша заявка одобрена.',
        read: false,
        createdAt: DateTime.now(),
      );

      final service = FakeNotificationService(
        mockNotifications: [mockNotif],
        pushEnabledValue: true,
      );
      final notifProvider = NotificationProvider(service: service);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<NotificationProvider>.value(value: notifProvider),
          ],
          child: MaterialApp(
            home: NotificationOverlay(
              showAllUnreadInitially: true,
              child: Scaffold(
                appBar: AppBar(
                  actions: [
                    NotificationBadge(
                      icon: const Icon(Icons.notifications),
                      onTap: () {},
                    ),
                  ],
                ),
                body: const Text('Home Screen'),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Trigger the listener
      notifProvider.notifyListeners();
      await tester.pump(); // Start overlay show
      await tester.pump(const Duration(milliseconds: 300)); // Complete animation

      // Overlay alert card should be visible
      expect(find.text('Заявка одобрена'), findsWidgets); // Found in both notification and overlay
      // Badge count should be 1
      expect(find.text('1'), findsOneWidget);

      // Drain the auto-dismiss timer (5s) and close animation (300ms)
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('NotificationOverlay does NOT display alert and badge count remains 0 when push notifications are disabled', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'notif_push_enabled_test@example.com': false,
      });

      final mockNotif = NotificationModel(
        id: 'approved-app-notif',
        userId: 'test-user-id',
        type: 'artist_application_approved',
        title: 'Заявка одобрена',
        message: 'Поздравляем! Ваша заявка одобрена.',
        read: false,
        createdAt: DateTime.now(),
      );

      final service = FakeNotificationService(
        mockNotifications: [mockNotif],
        pushEnabledValue: false, // push notifications disabled!
      );
      final notifProvider = NotificationProvider(service: service);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<NotificationProvider>.value(value: notifProvider),
          ],
          child: MaterialApp(
            home: NotificationOverlay(
              showAllUnreadInitially: true,
              child: Scaffold(
                appBar: AppBar(
                  actions: [
                    NotificationBadge(
                      icon: const Icon(Icons.notifications),
                      onTap: () {},
                    ),
                  ],
                ),
                body: const Text('Home Screen'),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Trigger listener
      notifProvider.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // No card alert should be shown
      expect(find.text('Заявка одобрена'), findsNothing);
      // Badge count should remain 0 / not found
      expect(find.text('1'), findsNothing);
    });
  });
}

class FakeNotificationService extends NotificationService {
  final List<NotificationModel> mockNotifications;
  bool isInitialized = false;
  bool pushEnabledValue;
  bool playlistsEnabledValue;
  bool socialEnabledValue;

  FakeNotificationService({
    this.mockNotifications = const [],
    this.pushEnabledValue = true,
    this.playlistsEnabledValue = true,
    this.socialEnabledValue = true,
  }) : super.forTesting();

  @override
  bool get isPushEnabled => pushEnabledValue;

  @override
  List<NotificationModel> get notifications {
    if (!pushEnabledValue) return [];
    return mockNotifications.where((n) {
      if (n.type == 'collab_invite' && !playlistsEnabledValue) return false;
      if (n.type == 'new_follower' && !socialEnabledValue) return false;
      return true;
    }).toList();
  }

  @override
  List<NotificationModel> get unreadNotifications =>
      notifications.where((n) => !n.read).toList();

  @override
  int get unreadCount => unreadNotifications.length;

  @override
  Future<void> initialize() async {
    isInitialized = true;
    final prefs = await SharedPreferences.getInstance();
    final email = 'test@example.com';
    pushEnabledValue = prefs.getBool('notif_push_enabled_$email') ?? true;
    playlistsEnabledValue = prefs.getBool('notif_playlists_enabled_$email') ?? true;
    socialEnabledValue = prefs.getBool('notif_social_enabled_$email') ?? false;
    notifyListeners();
  }

  @override
  Future<void> loadNotifications() async {
    notifyListeners();
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    final idx = mockNotifications.indexWhere((n) => n.id == notificationId);
    if (idx != -1) {
      final old = mockNotifications[idx];
      mockNotifications[idx] = NotificationModel(
        id: old.id,
        userId: old.userId,
        type: old.type,
        title: old.title,
        message: old.message,
        data: old.data,
        read: true,
        createdAt: old.createdAt,
      );
    }
    notifyListeners();
  }

  @override
  Future<void> markAllAsRead() async {
    for (int i = 0; i < mockNotifications.length; i++) {
      final old = mockNotifications[i];
      mockNotifications[i] = NotificationModel(
        id: old.id,
        userId: old.userId,
        type: old.type,
        title: old.title,
        message: old.message,
        data: old.data,
        read: true,
        createdAt: old.createdAt,
      );
    }
    notifyListeners();
  }
}

class FakeCollabPlaylistProvider extends ChangeNotifier implements CollabPlaylistProvider {
  List<CollabPlaylistModel> pendingInvites = [];

  @override
  Future<bool> acceptInvite(String playlistId) async {
    pendingInvites.removeWhere((i) => i.playlistId == playlistId);
    notifyListeners();
    return true;
  }

  @override
  Future<bool> declineInvite(String playlistId) async {
    pendingInvites.removeWhere((i) => i.playlistId == playlistId);
    notifyListeners();
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
