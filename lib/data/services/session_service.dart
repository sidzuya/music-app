import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class SessionService {
  static final SessionService instance = SessionService._();
  SessionService._();

  Future<Map<String, String>> getIpAndLocation() async {
    try {
      final response = await http.get(Uri.parse('https://ipapi.co/json/')).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final ip = data['ip']?.toString() ?? '127.0.0.1';
        final city = data['city']?.toString() ?? 'Unknown City';
        final country = data['country_name']?.toString() ?? 'Unknown Country';
        return {
          'ip': ip,
          'location': '$city, $country',
        };
      }
    } catch (e) {
      debugPrint('SessionService: Error getting IP/Location: $e');
    }
    return {
      'ip': '127.0.0.1',
      'location': 'Local Session',
    };
  }

  String getDeviceName() {
    if (kIsWeb) return 'Web Browser';
    try {
      // Use defaultTargetPlatform which is safe on all platforms
      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
          return 'Safari на iPhone';
        case TargetPlatform.android:
          return 'Chrome на Android';
        case TargetPlatform.macOS:
          return 'Chrome на macOS';
        case TargetPlatform.windows:
          return 'Firefox на Windows';
        case TargetPlatform.linux:
          return 'Firefox на Linux';
        case TargetPlatform.fuchsia:
          return 'Unknown Device';
      }
    } catch (_) {
      return 'Unknown Device';
    }
  }

  Future<void> registerNewSession(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final emailKey = email.toLowerCase().trim();
    if (emailKey.isEmpty) return;
    
    final ipLoc = await getIpAndLocation();
    final device = getDeviceName();
    
    final historyKey = 'login_history_list_$emailKey';
    final sessionsKey = 'active_sessions_list_$emailKey';
    
    final historyJson = prefs.getString(historyKey);
    List<Map<String, String>> history = [];
    if (historyJson != null) {
      try {
        final decoded = jsonDecode(historyJson) as List;
        history = decoded.map((item) => Map<String, String>.from(item as Map)).toList();
      } catch (_) {}
    }
    
    final sessionsJson = prefs.getString(sessionsKey);
    List<Map<String, String>> sessions = [];
    if (sessionsJson != null) {
      try {
        final decoded = jsonDecode(sessionsJson) as List;
        sessions = decoded.map((item) => Map<String, String>.from(item as Map)).toList();
      } catch (_) {}
    }

    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final newSession = {
      'id': newId,
      'device': device,
      'location': ipLoc['location']!,
      'ip': ipLoc['ip']!,
      'time': 'Активен сейчас',
      'lastActive': 'Текущая',
      'isCurrent': 'true',
    };
    
    // Mark previous current sessions as not current
    for (var s in sessions) {
      s['isCurrent'] = 'false';
      if (s['lastActive'] == 'Текущая') {
        s['lastActive'] = 'Недавно';
      }
    }
    for (var h in history) {
      h['isCurrent'] = 'false';
      if (h['time'] == 'Активен сейчас') {
        h['time'] = 'Недавно';
      }
    }
    
    // Check if this device already has a session in active sessions list
    // (e.g. to prevent listing multiple identical current device sessions on startup)
    sessions.removeWhere((s) => s['device'] == device && s['isCurrent'] == 'true');
    
    sessions.insert(0, newSession);
    history.insert(0, newSession);
    
    await prefs.setString(historyKey, jsonEncode(history));
    await prefs.setString(sessionsKey, jsonEncode(sessions));
  }
}
