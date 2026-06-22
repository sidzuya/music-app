import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:music_app/core/theme/app_theme.dart';
import 'package:music_app/data/models/user_model.dart';
import 'package:music_app/data/models/song_model.dart';
import 'package:music_app/data/models/friend_activity_model.dart';
import 'package:music_app/data/models/collab_playlist_model.dart';
import 'package:music_app/data/models/recommendation_mix_model.dart';
import 'package:music_app/data/services/follow_service.dart';
import 'package:music_app/data/services/live_room_service.dart';
import 'package:music_app/data/services/supabase_auth_service.dart';
import 'package:music_app/data/services/notification_service.dart';
import 'package:music_app/presentation/providers/auth_provider.dart';
import 'package:music_app/presentation/providers/locale_provider.dart';
import 'package:music_app/presentation/providers/music_provider.dart';
import 'package:music_app/presentation/providers/live_room_provider.dart';
import 'package:music_app/presentation/providers/friend_activity_provider.dart';
import 'package:music_app/presentation/providers/playlist_provider.dart';
import 'package:music_app/presentation/providers/theme_provider.dart';
import 'package:music_app/presentation/providers/recommendation_provider.dart';
import 'package:music_app/presentation/providers/follow_provider.dart';
import 'package:music_app/presentation/providers/notification_provider.dart';
import 'package:music_app/presentation/providers/collab_playlist_provider.dart';
import 'package:music_app/presentation/screens/settings/account_settings_screen.dart';
import 'package:music_app/presentation/screens/auth/login_screen.dart';
import 'package:music_app/presentation/screens/home/home_screen.dart';

// Fake HttpOverrides to prevent network requests during tests and simulate success
class MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return FakeHttpClient();
  }
}

class FakeHttpClient extends Fake implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return FakeHttpClientRequest();
  }
  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    return FakeHttpClientRequest();
  }
  @override
  bool get autoUncompress => true;
  @override
  set autoUncompress(bool value) {}
  @override
  void close({bool force = false}) {}
}

class FakeHttpClientRequest extends Fake implements HttpClientRequest {
  final FakeHttpHeaders _headers = FakeHttpHeaders();
  
  @override
  HttpHeaders get headers => _headers;

  @override
  int contentLength = 0;

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  bool persistentConnection = true;

  @override
  void write(Object? obj) {}

  @override
  void add(List<int> data) {}

  @override
  Future<dynamic> addStream(Stream<List<int>> stream) async {
    await stream.drain();
  }

  @override
  Future<HttpClientResponse> close() async {
    return FakeHttpClientResponse();
  }
}

class FakeHttpHeaders extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void forEach(void Function(String name, List<String> values) f) {}
  @override
  ContentType? contentType;
  @override
  int contentLength = 0;
}

class FakeHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  int get statusCode => 200;

  @override
  String get reasonPhrase => 'OK';

  @override
  int get contentLength => -1;

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => true;

  @override
  HttpHeaders get headers => FakeHttpHeaders();

  @override
  List<RedirectInfo> get redirects => [];

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final data = utf8.encode('{"success": true}');
    return Stream<List<int>>.fromIterable([data]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class FakeLocaleProvider extends ChangeNotifier implements LocaleProvider {
  @override
  String getString(String key) {
    switch (key) {
      case 'account':
        return 'Аккаунт';
      case 'two_factor_auth':
        return 'Двухфакторная аутентификация';
      case 'login_history':
        return 'История входов';
      case 'ad_data':
        return 'Данные для рекламы';
      case 'cancel':
        return 'Отмена';
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
  );
  bool _isLoggedIn = true;

  @override
  UserModel? get currentUser => _currentUser;

  @override
  bool get isLoggedIn => _isLoggedIn;

  @override
  Future<AuthResult> login({required String email, required String password}) async {
    _currentUser = UserModel(
      id: 1,
      email: email,
      username: 'testuser',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _isLoggedIn = true;
    notifyListeners();
    return AuthResult(success: true, message: 'Success', user: _currentUser);
  }

  @override
  Future<void> logout() async {
    _currentUser = null;
    _isLoggedIn = false;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeMusicProvider extends ChangeNotifier implements MusicProvider {
  @override
  SongModel? get currentSong => null;
  @override
  bool get isPlaying => false;
  @override
  List<SongModel> get recentlyPlayed => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakePlaylistProvider extends ChangeNotifier implements PlaylistProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeLiveRoomProvider extends ChangeNotifier implements LiveRoomProvider {
  @override
  LiveRoom? get currentRoom => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFriendActivityProvider extends ChangeNotifier implements FriendActivityProvider {
  @override
  bool get isLoading => false;
  @override
  List<FriendActivityModel> get activities => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeThemeProvider extends ChangeNotifier implements ThemeProvider {
  @override
  bool get showAlbumArt => true;
  @override
  bool get animationsEnabled => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRecommendationProvider extends ChangeNotifier implements RecommendationProvider {
  @override
  List<RecommendationMixModel> get dailyMixes => [];
  @override
  bool get hasMixes => false;
  @override
  bool get isLoading => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFollowProvider extends ChangeNotifier implements FollowProvider {
  @override
  FollowCounts get counts => FollowCounts.empty;
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
  HttpOverrides.global = MockHttpOverrides();
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    HttpOverrides.global = MockHttpOverrides();
    SharedPreferences.setMockInitialValues({});
    
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) {
        return;
      }
      previousOnError?.call(details);
    };

    // Initialize a mock Supabase instance asynchronously inside setUp with custom local storage
    try {
      await Supabase.initialize(
        url: 'https://placeholder-project.supabase.co',
        anonKey: 'placeholderAnonKey',
        authOptions: const FlutterAuthClientOptions(
          localStorage: MockLocalStorage(),
        ),
      );
    } catch (_) {
      // Already initialized
    }
  });

  Widget createAccountSettingsScreen({FakeAuthProvider? authProvider}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LocaleProvider>.value(value: FakeLocaleProvider()),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider ?? FakeAuthProvider()),
        ChangeNotifierProvider<ThemeProvider>.value(value: FakeThemeProvider()),
      ],
      child: const MaterialApp(
        home: AccountSettingsScreen(),
      ),
    );
  }

  Widget createLoginScreen({FakeAuthProvider? authProvider}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LocaleProvider>.value(value: FakeLocaleProvider()),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider ?? FakeAuthProvider()),
        ChangeNotifierProvider<MusicProvider>.value(value: FakeMusicProvider()),
        ChangeNotifierProvider<LiveRoomProvider>.value(value: FakeLiveRoomProvider()),
        ChangeNotifierProvider<FriendActivityProvider>.value(value: FakeFriendActivityProvider()),
        ChangeNotifierProvider<PlaylistProvider>.value(value: FakePlaylistProvider()),
        ChangeNotifierProvider<ThemeProvider>.value(value: FakeThemeProvider()),
        ChangeNotifierProvider<RecommendationProvider>.value(value: FakeRecommendationProvider()),
        ChangeNotifierProvider<FollowProvider>.value(value: FakeFollowProvider()),
        ChangeNotifierProvider<NotificationProvider>.value(value: FakeNotificationProvider()),
        ChangeNotifierProvider<CollabPlaylistProvider>.value(value: FakeCollabPlaylistProvider()),
      ],
      child: MaterialApp(
        routes: {
          '/home': (context) => const Scaffold(body: Text('HomeScreen')),
        },
        home: const LoginScreen(),
      ),
    );
  }

  group('AccountSettingsScreen Interactive 2FA & Ad settings tests', () {
    testWidgets('Tapping 2FA opens setup modal sheet, enters email, and transitions', (WidgetTester tester) async {
      await tester.pumpWidget(createAccountSettingsScreen());
      await tester.pumpAndSettle();

      // Find the 2FA list tile, scroll to it to avoid off-screen issues and tap
      final tile = find.text('Двухфакторная аутентификация');
      expect(tile, findsOneWidget);
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();

      // Verification of modal details
      expect(find.text('Настроить защиту'), findsOneWidget);
      await tester.tap(find.text('Настроить защиту'));
      await tester.pumpAndSettle();

      // Enter email and send code
      expect(find.text('Введите Email для отправки одноразового кода подтверждения:'), findsOneWidget);
      final emailField = find.descendant(
        of: find.byType(AnimatedContainer),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(emailField, 'my-2fa@example.com');
      await tester.tap(find.text('Отправить код'));
      await tester.pump();
      await tester.pumpAndSettle();

      // Confirm verification step transition
      expect(find.textContaining('Код подтверждения был отправлен на почту'), findsOneWidget);
    });

  });

  group('LoginScreen 2FA Verification flow tests', () {
    testWidgets('If 2FA is enabled, successful password verification triggers 2FA modal', (WidgetTester tester) async {
      final emailKey = 'test@example.com';
      SharedPreferences.setMockInitialValues({
        '2fa_enabled_$emailKey': true,
        '2fa_email_$emailKey': 'my-secure-email@example.com',
        '2fa_backup_codes_$emailKey': ['9999-8888'],
      });

      final authProvider = FakeAuthProvider();
      await tester.pumpWidget(createLoginScreen(authProvider: authProvider));
      await tester.pumpAndSettle();

      // Enter email and password
      await tester.enterText(find.bySemanticsLabel('Email'), emailKey);
      await tester.enterText(find.bySemanticsLabel('Password'), 'anypassword');
      
      // Tap sign in
      await tester.tap(find.text('Sign In'));
      await tester.pump(); // Starts validation and login call
      await tester.pump(const Duration(milliseconds: 100)); // Triggers the sheet
      await tester.pumpAndSettle();

      // Confirm we show the 2FA verification sheet
      expect(find.text('Двухфакторная проверка'), findsOneWidget);
      expect(find.textContaining('Код подтверждения был отправлен на почту my-secure-email@example.com'), findsOneWidget);

      // Enter incorrect code
      final codeField = find.descendant(
        of: find.byType(StatefulBuilder),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(codeField, 'wrong-code');
      await tester.tap(find.text('Подтвердить'));
      await tester.pumpAndSettle();
      expect(find.text('Неверный код подтверждения или резервный код'), findsOneWidget);

      // Enter correct backup code
      await tester.enterText(codeField, '9999-8888');
      await tester.tap(find.text('Подтвердить'));
      
      // Wait for the modal sheet animation to close (at least 300ms, using 500ms)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // The sheet should close
      expect(find.text('Двухфакторная проверка'), findsNothing);
    });

    testWidgets('Canceling the 2FA modal resets login status', (WidgetTester tester) async {
      final emailKey = 'test@example.com';
      SharedPreferences.setMockInitialValues({
        '2fa_enabled_$emailKey': true,
        '2fa_email_$emailKey': 'my-secure-email@example.com',
      });

      final authProvider = FakeAuthProvider();
      await tester.pumpWidget(createLoginScreen(authProvider: authProvider));
      await tester.pumpAndSettle();

      await tester.enterText(find.bySemanticsLabel('Email'), emailKey);
      await tester.enterText(find.bySemanticsLabel('Password'), 'password');
      await tester.tap(find.text('Sign In'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('Двухфакторная проверка'), findsOneWidget);

      // Tap cancel
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();

      // User should be logged out
      expect(authProvider.isLoggedIn, false);
      expect(find.textContaining('Вход отменен или неверный код 2FA'), findsOneWidget);
    });
  });
}
