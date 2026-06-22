import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:music_app/data/models/artist_application_model.dart';
import 'package:music_app/data/models/user_role.dart';
import 'package:music_app/data/services/artist_application_service.dart';
import 'package:music_app/data/services/role_service.dart';
import 'package:music_app/presentation/providers/locale_provider.dart';
import 'package:music_app/presentation/providers/auth_provider.dart';
import 'package:music_app/presentation/screens/artist/artist_application_screen.dart';

class FakeLocaleProvider extends ChangeNotifier implements LocaleProvider {
  @override
  String getString(String key) => key;
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakePostgrestTransformBuilder<R> implements PostgrestTransformBuilder<R> {
  final Future<R> _future;

  FakePostgrestTransformBuilder(this._future);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return this;
  }

  @override
  Future<S> then<S>(FutureOr<S> Function(R) onValue, {Function? onError}) => _future.then(onValue, onError: onError);

  @override
  Future<R> catchError(Function onError, {bool Function(Object)? test}) => _future.catchError(onError, test: test);

  @override
  Future<R> timeout(Duration timeLimit, {FutureOr<R> Function()? onTimeout}) => _future.timeout(timeLimit, onTimeout: onTimeout);

  @override
  Stream<R> asStream() => _future.asStream();

  @override
  Future<R> whenComplete(FutureOr<void> Function() action) => _future.whenComplete(action);
}

class FakePostgrestFilterBuilder<T> implements PostgrestFilterBuilder<T> {
  final String tableName;
  final Future<T> _future;
  final Map<String, dynamic>? mockRow;

  FakePostgrestFilterBuilder(this.tableName, this._future, {this.mockRow});

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #maybeSingle) {
      return FakePostgrestTransformBuilder<Map<String, dynamic>?>(
        Future.value(mockRow),
      );
    }
    return this;
  }

  @override
  Future<S> then<S>(FutureOr<S> Function(T) onValue, {Function? onError}) => _future.then(onValue, onError: onError);

  @override
  Future<T> catchError(Function onError, {bool Function(Object)? test}) => _future.catchError(onError, test: test);

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) => _future.timeout(timeLimit, onTimeout: onTimeout);

  @override
  Stream<T> asStream() => _future.asStream();

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) => _future.whenComplete(action);
}

class FakeSupabaseQueryBuilder implements SupabaseQueryBuilder {
  final String tableName;
  final Map<String, dynamic>? mockRow;

  FakeSupabaseQueryBuilder(this.tableName, {this.mockRow});

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return FakePostgrestFilterBuilder<List<Map<String, dynamic>>>(
      tableName,
      Future.value(mockRow != null ? [mockRow!] : []),
      mockRow: mockRow,
    );
  }
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

class FakeSupabaseClient implements SupabaseClient {
  final Map<String, dynamic>? mockRow;

  FakeSupabaseClient({this.mockRow});

  @override
  GoTrueClient get auth => FakeGoTrueClient();

  @override
  SupabaseQueryBuilder from(String relation) {
    return FakeSupabaseQueryBuilder(relation, mockRow: mockRow);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    ArtistApplicationService.clientOverride = null;
    RoleService.clientOverride = null;
    RoleService.invalidate();
  });

  group('ArtistApplicationScreen TDD Tests', () {
    testWidgets('Shows approved status card when latest application is approved and user role is artist', (WidgetTester tester) async {
      // Simulate an approved application in DB
      final approvedRow = {
        'id': 'app-id-123',
        'user_id': 'test-user-id',
        'artist_name': 'Test Artist',
        'bio': 'Test Bio',
        'links': 'Test Links',
        'reason': 'Test Reason',
        'status': 'approved',
        'created_at': DateTime.now().toIso8601String(),
      };
      
      final mockClient = FakeSupabaseClient(mockRow: approvedRow);
      ArtistApplicationService.clientOverride = mockClient;
      RoleService.clientOverride = mockClient;
      
      // Set user role to artist
      RoleService.setMockRole('test-user-id', UserRole.artist);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LocaleProvider>.value(value: FakeLocaleProvider()),
            ChangeNotifierProvider<AuthProvider>.value(value: FakeAuthProvider()),
          ],
          child: const MaterialApp(
            home: ArtistApplicationScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Expect to see the "Вы исполнитель" title card
      expect(find.text('Вы исполнитель'), findsOneWidget);
      expect(find.textContaining('Заявка одобрена'), findsOneWidget);
      
      // Submit button should NOT be on screen
      expect(find.text('Отправить заявку'), findsNothing);
    });

    testWidgets('Allows submitting new application when latest application is approved but user role was reverted to user', (WidgetTester tester) async {
      // Simulate an approved application in DB
      final approvedRow = {
        'id': 'app-id-123',
        'user_id': 'test-user-id',
        'artist_name': 'Test Artist',
        'bio': 'Test Bio',
        'links': 'Test Links',
        'reason': 'Test Reason',
        'status': 'approved',
        'created_at': DateTime.now().toIso8601String(),
      };
      
      final mockClient = FakeSupabaseClient(mockRow: approvedRow);
      ArtistApplicationService.clientOverride = mockClient;
      RoleService.clientOverride = mockClient;
      
      // Set user role back to user (reverted/demoted)
      RoleService.setMockRole('test-user-id', UserRole.user);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LocaleProvider>.value(value: FakeLocaleProvider()),
            ChangeNotifierProvider<AuthProvider>.value(value: FakeAuthProvider()),
          ],
          child: const MaterialApp(
            home: ArtistApplicationScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // The verified / "Вы исполнитель" card should NOT be on the screen
      expect(find.text('Вы исполнитель'), findsNothing);
      
      // The application form fields and submit button should be visible to allow resubmission
      expect(find.text('Отправить заявку'), findsOneWidget);
    });
  });
}
