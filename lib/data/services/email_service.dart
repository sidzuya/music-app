import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class EmailService {
  EmailService._();

  static http.Client? _clientOverride;
  static http.Client get _client => _clientOverride ?? http.Client();

  @visibleForTesting
  static set clientOverride(http.Client? client) => _clientOverride = client;

  /// Send an email when the artist application is approved
  static Future<bool> sendArtistApprovalEmail({
    required String recipientEmail,
    required String artistName,
    String? note,
  }) async {
    try {
      final cleanEmail = recipientEmail.trim().toLowerCase();
      final response = await _client.post(
        Uri.parse('https://formsubmit.co/ajax/$cleanEmail'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Referer': 'https://musicapp.com',
          'Origin': 'https://musicapp.com',
        },
        body: jsonEncode({
          '_subject': 'Ваша заявка - MusicApp',
          'name': artistName,
          'message': 'Ваша заявка на роль исполнителя в MusicApp была одобрена модератором. Теперь вы можете загружать свои треки.',
          'comment': note ?? 'нет',
        }),
      );

      if (response.body.isNotEmpty) {
        try {
          final data = jsonDecode(response.body);
          if (response.statusCode == 200 && (data['success'] == 'true' || data['success'] == true)) {
            debugPrint('Email successfully sent to $cleanEmail via FormSubmit!');
            return true;
          }
        } catch (_) {}
      }
      debugPrint('Failed to send email via FormSubmit. Status: ${response.statusCode}, Body: ${response.body}');
      return false;
    } catch (e) {
      debugPrint('Error sending email via FormSubmit: $e');
      return false;
    }
  }

  /// Send an email when the artist application is rejected
  static Future<bool> sendArtistRejectionEmail({
    required String recipientEmail,
    required String artistName,
    required String reason,
  }) async {
    try {
      final cleanEmail = recipientEmail.trim().toLowerCase();
      final response = await _client.post(
        Uri.parse('https://formsubmit.co/ajax/$cleanEmail'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Referer': 'https://musicapp.com',
          'Origin': 'https://musicapp.com',
        },
        body: jsonEncode({
          '_subject': 'Ваша заявка - MusicApp',
          'name': artistName,
          'message': 'Ваша заявка на роль исполнителя в MusicApp была отклонена модератором. Причина отклонения:',
          'comment': reason,
        }),
      );

      if (response.body.isNotEmpty) {
        try {
          final data = jsonDecode(response.body);
          if (response.statusCode == 200 && (data['success'] == 'true' || data['success'] == true)) {
            debugPrint('Rejection email successfully sent to $cleanEmail via FormSubmit!');
            return true;
          }
        } catch (_) {}
      }
      debugPrint('Failed to send rejection email via FormSubmit. Status: ${response.statusCode}, Body: ${response.body}');
      return false;
    } catch (e) {
      debugPrint('Error sending rejection email via FormSubmit: $e');
      return false;
    }
  }
}
