import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music_app/data/services/email_service.dart';

void main() {
  group('EmailService FormSubmit Tests', () {
    tearDown(() {
      EmailService.clientOverride = null;
    });

    test('Sends HTTP request to FormSubmit API and returns true on success', () async {
      bool apiCalled = false;
      
      final mockHttpClient = MockClient((request) async {
        if (request.url.toString() == 'https://formsubmit.co/ajax/applicant@example.com') {
          apiCalled = true;
          expect(request.method, 'POST');
          expect(request.headers['Content-Type'], startsWith('application/json'));
          expect(request.headers['Accept'], 'application/json');

          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['_subject'], equals('Ваша заявка - MusicApp'));
          expect(body['name'], 'Superstar Artist');
          expect(body['message'], contains('одобрена'));
          expect(body['comment'], 'Welcome aboard!');

          return http.Response(jsonEncode({'success': 'true'}), 200);
        }
        return http.Response('Not Found', 404);
      });

      EmailService.clientOverride = mockHttpClient;

      final result = await EmailService.sendArtistApprovalEmail(
        recipientEmail: 'applicant@example.com',
        artistName: 'Superstar Artist',
        note: 'Welcome aboard!',
      );

      expect(result, isTrue);
      expect(apiCalled, isTrue);
    });

    test('Returns false when FormSubmit API returns an error or success=false', () async {
      final mockHttpClient = MockClient((request) async {
        return http.Response(jsonEncode({'success': 'false', 'message': 'Limit exceeded'}), 400);
      });

      EmailService.clientOverride = mockHttpClient;

      final result = await EmailService.sendArtistApprovalEmail(
        recipientEmail: 'applicant@example.com',
        artistName: 'Superstar Artist',
      );

      expect(result, isFalse);
    });

    test('Sends HTTP request to FormSubmit API and returns true on rejection email success', () async {
      bool apiCalled = false;
      
      final mockHttpClient = MockClient((request) async {
        if (request.url.toString() == 'https://formsubmit.co/ajax/applicant@example.com') {
          apiCalled = true;
          expect(request.method, 'POST');
          expect(request.headers['Content-Type'], startsWith('application/json'));
          expect(request.headers['Accept'], 'application/json');

          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['_subject'], equals('Ваша заявка - MusicApp'));
          expect(body['name'], 'Rejected Artist');
          expect(body['message'], contains('Ваша заявка'));
          expect(body['comment'], 'Invalid links');

          return http.Response(jsonEncode({'success': 'true'}), 200);
        }
        return http.Response('Not Found', 404);
      });

      EmailService.clientOverride = mockHttpClient;

      final result = await EmailService.sendArtistRejectionEmail(
        recipientEmail: 'applicant@example.com',
        artistName: 'Rejected Artist',
        reason: 'Invalid links',
      );

      expect(result, isTrue);
      expect(apiCalled, isTrue);
    });
  });
}
