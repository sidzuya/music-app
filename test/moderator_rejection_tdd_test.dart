import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:music_app/data/models/artist_application_model.dart';
import 'package:music_app/data/services/artist_application_service.dart';
import 'package:music_app/data/services/email_service.dart';
import 'package:music_app/presentation/providers/locale_provider.dart';
import 'package:music_app/presentation/screens/moderator/moderator_panel_screen.dart';

// Fake implementations for tests

class FakeLocaleProvider extends ChangeNotifier implements LocaleProvider {
  @override
  String getString(String key) => key;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeGoTrueClient implements GoTrueClient {
  @override
  User? get currentUser => User(
        id: 'moderator-user-id',
        email: 'moderator@example.com',
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
  Future<S> then<S>(FutureOr<S> Function(R) onValue, {Function? onError}) =>
      _future.then(onValue, onError: onError);
}

class FakePostgrestFilterBuilder<T> implements PostgrestFilterBuilder<T> {
  final Future<T> _future;
  FakePostgrestFilterBuilder(this._future);

  @override
  dynamic noSuchMethod(Invocation invocation) => this;

  @override
  Future<S> then<S>(FutureOr<S> Function(T) onValue, {Function? onError}) =>
      _future.then(onValue, onError: onError);
}

class FakeSupabaseQueryBuilder implements SupabaseQueryBuilder {
  final List<Map<String, dynamic>> mockRows;
  FakeSupabaseQueryBuilder(this.mockRows);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #select) {
      return FakePostgrestFilterBuilder<List<Map<String, dynamic>>>(
        Future.value(mockRows),
      );
    }
    return FakePostgrestFilterBuilder<List<Map<String, dynamic>>>(
      Future.value([]),
    );
  }
}

class FakeSupabaseClient implements SupabaseClient {
  final List<Map<String, dynamic>> mockRows;
  final Function(String, Map<String, dynamic>) onRpcCalled;

  FakeSupabaseClient({required this.mockRows, required this.onRpcCalled});

  @override
  GoTrueClient get auth => FakeGoTrueClient();

  @override
  SupabaseQueryBuilder from(String relation) {
    if (relation == 'profiles') {
      return FakeSupabaseQueryBuilder([
        {'id': 'applicant-user-id', 'username': 'artist_user', 'email': 'applicant@example.com'}
      ]);
    }
    return FakeSupabaseQueryBuilder(mockRows);
  }

  @override
  PostgrestFilterBuilder<T> rpc<T>(
    String fn, {
    Map<String, dynamic>? params,
    dynamic get,
  }) {
    onRpcCalled(fn, params ?? {});
    return FakePostgrestFilterBuilder<T>(Future.value(null as T)) as PostgrestFilterBuilder<T>;
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
    EmailService.clientOverride = null;
  });

  group('Moderator Panel Rejection TDD Tests', () {
    testWidgets('Rejecting artist application calls reject RPC and triggers rejection email', (WidgetTester tester) async {
      final mockAppRow = {
        'id': 'app-12345',
        'user_id': 'applicant-user-id',
        'artist_name': 'Cool Artist Name',
        'bio': 'I sing pop music',
        'links': 'http://youtube.com',
        'reason': 'I want to share music',
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      };

      String? rpcName;
      Map<String, dynamic>? rpcParams;

      final fakeSupabase = FakeSupabaseClient(
        mockRows: [mockAppRow],
        onRpcCalled: (fn, params) {
          rpcName = fn;
          rpcParams = params;
        },
      );

      ArtistApplicationService.clientOverride = fakeSupabase;

      // Mock FormSubmit email response
      bool emailSent = false;
      String? sentEmailRecipient;
      String? sentEmailReason;
      String? sentEmailArtist;

      final mockHttpClient = MockClient((request) async {
        if (request.url.toString() == 'https://formsubmit.co/ajax/applicant@example.com') {
          emailSent = true;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          sentEmailRecipient = 'applicant@example.com';
          sentEmailArtist = body['name'];
          sentEmailReason = body['comment'];
          return http.Response(jsonEncode({'success': true}), 200);
        }
        return http.Response('Not Found', 404);
      });

      EmailService.clientOverride = mockHttpClient;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LocaleProvider>.value(value: FakeLocaleProvider()),
          ],
          child: const MaterialApp(
            home: ModeratorPanelScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the application details are rendered
      expect(find.text('Cool Artist Name'), findsOneWidget);
      expect(find.textContaining('I sing pop music'), findsOneWidget);

      // Tap on Reject ("Отклонить") button
      final rejectButton = find.text('Отклонить');
      expect(rejectButton, findsOneWidget);
      await tester.tap(rejectButton);
      await tester.pumpAndSettle();

      // An alert dialog should appear asking for rejection reason
      expect(find.textContaining('Причина отклонения'), findsOneWidget);

      // Fill in rejection reason
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);
      await tester.enterText(textField, 'Invalid link formatting');
      await tester.pumpAndSettle();

      // Tap OK/Submit in the dialog
      final okButton = find.text('Готово');
      expect(okButton, findsOneWidget);
      await tester.tap(okButton);
      
      // Wait for async operations to complete
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      // Verify RPC reject function was called with correct parameters
      expect(rpcName, equals('reject_artist_application'));
      expect(rpcParams?['application_id'], equals('app-12345'));
      expect(rpcParams?['note'], equals('Invalid link formatting'));

      // Verify that rejection email request was fired through FormSubmit
      expect(emailSent, isTrue);
      expect(sentEmailRecipient, equals('applicant@example.com'));
      expect(sentEmailArtist, equals('Cool Artist Name'));
      expect(sentEmailReason, equals('Invalid link formatting'));
    });
  });
}
