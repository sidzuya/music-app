import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:music_app/presentation/providers/auth_provider.dart';
import 'package:music_app/presentation/providers/music_provider.dart';
import 'package:music_app/presentation/providers/locale_provider.dart';
import 'package:music_app/presentation/providers/notification_provider.dart';
import 'package:music_app/presentation/providers/collab_playlist_provider.dart';
import 'package:music_app/presentation/providers/follow_provider.dart';
import 'package:music_app/presentation/providers/live_room_provider.dart';
import 'package:music_app/presentation/providers/recommendation_provider.dart';
import 'package:music_app/presentation/providers/friend_activity_provider.dart';
import 'package:music_app/presentation/screens/home/home_screen.dart';
import 'package:music_app/data/models/song_model.dart';
import 'package:music_app/data/models/user_model.dart';
import 'package:music_app/data/models/collab_playlist_model.dart';
import 'package:music_app/data/models/recommendation_mix_model.dart';
import 'package:music_app/data/models/friend_activity_model.dart';
import 'package:music_app/data/models/user_role.dart';
import 'package:music_app/data/services/notification_service.dart';
import 'package:music_app/data/services/live_room_service.dart';
import 'package:music_app/data/services/follow_service.dart';
import 'package:music_app/data/services/role_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Fakes
class FakeLocaleProvider extends ChangeNotifier implements LocaleProvider {
  @override
  String getString(String key) => key;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  bool get isLoggedIn => true;
  @override
  UserModel? get currentUser => UserModel(
    id: 1,
    email: 'test@example.com',
    username: 'testuser',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeMusicProvider extends ChangeNotifier implements MusicProvider {
  @override
  SongModel? get currentSong => null;
  @override
  List<SongModel> get playlist => [];
  @override
  List<SongModel> get recentlyPlayed => [];
  @override
  int get currentIndex => 0;
  @override
  bool get isPlaying => false;
  @override
  bool get isLoading => false;
  @override
  Duration get duration => Duration.zero;
  @override
  Duration get position => Duration.zero;
  @override
  bool get isShuffleEnabled => false;
  @override
  RepeatMode get repeatMode => RepeatMode.off;
  @override
  double get volume => 0.7;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeNotificationProvider extends ChangeNotifier implements NotificationProvider {
  @override
  int get unreadCount => 0;
  @override
  List<NotificationModel> get notifications => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCollabPlaylistProvider extends ChangeNotifier implements CollabPlaylistProvider {
  @override
  List<CollabPlaylistModel> get pendingInvites => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFollowProvider extends ChangeNotifier implements FollowProvider {
  @override
  FollowCounts get counts => FollowCounts.empty;
  @override
  Set<String> get followingIds => {};
  @override
  bool get isLoading => false;
  @override
  bool isFollowing(String userId) => false;
  @override
  Future<void> refresh() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeLiveRoomProvider extends ChangeNotifier implements LiveRoomProvider {
  @override
  LiveRoom? get currentRoom => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRecommendationProvider extends ChangeNotifier implements RecommendationProvider {
  @override
  List<RecommendationMixModel> get dailyMixes => [];
  @override
  bool get isLoading => false;
  @override
  bool get hasMixes => false;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> refreshRecommendations({bool force = false}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFriendActivityProvider extends ChangeNotifier implements FriendActivityProvider {
  @override
  List<FriendActivityModel> get activities => [];
  @override
  bool get isLoading => false;
  @override
  Future<void> refreshActivities() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeGoTrueClient implements GoTrueClient {
  @override
  User? get currentUser => User(
        id: 'test-user-id',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakePostgrestTransformBuilder<R> implements PostgrestTransformBuilder<R> {
  final Future<R> _future;
  FakePostgrestTransformBuilder(this._future);
  @override
  dynamic noSuchMethod(Invocation invocation) => this;
  @override
  Future<S> then<S>(FutureOr<S> Function(R) onValue, {Function? onError}) => _future.then(onValue, onError: onError);
}

class FakePostgrestFilterBuilder<T> implements PostgrestFilterBuilder<T> {
  final Future<T> _future;
  final Map<String, dynamic>? mockRow;
  FakePostgrestFilterBuilder(this._future, {this.mockRow});
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #maybeSingle) {
      return FakePostgrestTransformBuilder<Map<String, dynamic>?>(
        Future.value(mockRow),
      );
    }
    return this;
  }
}

class FakeSupabaseQueryBuilder implements SupabaseQueryBuilder {
  final Map<String, dynamic>? mockRow;
  FakeSupabaseQueryBuilder({this.mockRow});
  @override
  dynamic noSuchMethod(Invocation invocation) {
    return FakePostgrestFilterBuilder<List<Map<String, dynamic>>>(
      Future.value(mockRow != null ? [mockRow!] : []),
      mockRow: mockRow,
    );
  }
}

class FakeSupabaseClient implements SupabaseClient {
  @override
  GoTrueClient get auth => FakeGoTrueClient();

  @override
  SupabaseQueryBuilder from(String relation) {
    return FakeSupabaseQueryBuilder(mockRow: {'role': 'user'});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    final mockClient = FakeSupabaseClient();
    RoleService.clientOverride = mockClient;
    RoleService.setMockRole('test-user-id', UserRole.user);
  });

  tearDown(() {
    RoleService.clientOverride = null;
    RoleService.invalidate();
  });

  group('HomeScreen Adaptive Responsiveness Tests', () {
    testWidgets('renders desktop split layout on wide screens (>= 900px)', (WidgetTester tester) async {
      final testWidget = MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(create: (_) => FakeAuthProvider()),
          ChangeNotifierProvider<MusicProvider>(create: (_) => FakeMusicProvider()),
          ChangeNotifierProvider<LocaleProvider>(create: (_) => FakeLocaleProvider()),
          ChangeNotifierProvider<NotificationProvider>(create: (_) => FakeNotificationProvider()),
          ChangeNotifierProvider<CollabPlaylistProvider>(create: (_) => FakeCollabPlaylistProvider()),
          ChangeNotifierProvider<FollowProvider>(create: (_) => FakeFollowProvider()),
          ChangeNotifierProvider<LiveRoomProvider>(create: (_) => FakeLiveRoomProvider()),
          ChangeNotifierProvider<RecommendationProvider>(create: (_) => FakeRecommendationProvider()),
          ChangeNotifierProvider<FriendActivityProvider>(create: (_) => FakeFriendActivityProvider()),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      );

      // Widescreen width: 1200px
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(testWidget);
      await tester.pump();

      // Desktop sidebar navigation should be found
      expect(find.text('Главная'), findsOneWidget);
      expect(find.text('Поиск'), findsOneWidget);
      expect(find.text('AI Плейлист'), findsOneWidget);
      
      // Bottom navigation bar should not be present (it's mobile only)
      expect(find.byType(BottomNavigationBar), findsNothing);

      await tester.pump(const Duration(seconds: 1));

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('renders mobile layout on narrow screens (< 900px)', (WidgetTester tester) async {
      final testWidget = MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(create: (_) => FakeAuthProvider()),
          ChangeNotifierProvider<MusicProvider>(create: (_) => FakeMusicProvider()),
          ChangeNotifierProvider<LocaleProvider>(create: (_) => FakeLocaleProvider()),
          ChangeNotifierProvider<NotificationProvider>(create: (_) => FakeNotificationProvider()),
          ChangeNotifierProvider<CollabPlaylistProvider>(create: (_) => FakeCollabPlaylistProvider()),
          ChangeNotifierProvider<FollowProvider>(create: (_) => FakeFollowProvider()),
          ChangeNotifierProvider<LiveRoomProvider>(create: (_) => FakeLiveRoomProvider()),
          ChangeNotifierProvider<RecommendationProvider>(create: (_) => FakeRecommendationProvider()),
          ChangeNotifierProvider<FriendActivityProvider>(create: (_) => FakeFriendActivityProvider()),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      );

      // Narrow screen width: 600px
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(testWidget);
      await tester.pump();

      // Mobile BottomNavigationBar should be found
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      
      // Desktop sidebar should not be visible (no "Главная" sidebar items)
      expect(find.text('Главная'), findsNothing);

      await tester.pump(const Duration(seconds: 1));

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
