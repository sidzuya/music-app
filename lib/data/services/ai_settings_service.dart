import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';

class AiSettingsService {
  AiSettingsService._();

  static final AiSettingsService instance = AiSettingsService._();

  static const String _playlistAiApiKeyKey = 'playlist_ai_api_key';

  Future<String?> getOpenAiApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_playlistAiApiKeyKey)?.trim();
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }

    final bundledKey = AppConstants.googleAiApiKey.trim();
    if (bundledKey.isNotEmpty) {
      return bundledKey;
    }

    return null;
  }

  Future<bool> isUsingBundledAiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_playlistAiApiKeyKey)?.trim();
    if (stored != null && stored.isNotEmpty) {
      return false;
    }

    return AppConstants.googleAiApiKey.trim().isNotEmpty;
  }

  Future<bool> hasOpenAiApiKey() async {
    final key = await getOpenAiApiKey();
    return key != null && key.isNotEmpty;
  }

  Future<void> saveOpenAiApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_playlistAiApiKeyKey, apiKey.trim());
  }

  Future<void> clearOpenAiApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_playlistAiApiKeyKey);
  }

  String maskKey(String apiKey) {
    final trimmed = apiKey.trim();
    if (trimmed.length <= 8) {
      return '********';
    }

    final start = trimmed.substring(0, 6);
    final end = trimmed.substring(trimmed.length - 4);
    return '$start...$end';
  }
}
