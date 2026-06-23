import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/user_model.dart';
import '../../data/services/supabase_auth_service.dart';
import '../../data/services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider with ChangeNotifier {
  final SupabaseAuthService _authService = SupabaseAuthService.instance;
  
  UserModel? _currentUser;
  bool _isLoading = false;
  bool _isLoggedIn = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;

  AuthProvider() {
    _checkLoginStatus();
  }

  Future<UserModel> _mergeLocalPrivacySettings(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    final email = user.email.toLowerCase().trim();
    if (email.isEmpty) return user;
    
    final localProfile = prefs.getBool('privacy_profile_visible_$email');
    final localPlaylists = prefs.getBool('privacy_playlists_visible_$email');
    final localFollowers = prefs.getBool('privacy_followers_visible_$email');
    final localListening = prefs.getBool('privacy_listening_activity_$email');
    
    if (localProfile == null && localPlaylists == null && localFollowers == null && localListening == null) {
      await prefs.setBool('privacy_profile_visible_$email', user.profileVisible);
      await prefs.setBool('privacy_playlists_visible_$email', user.playlistsVisible);
      await prefs.setBool('privacy_followers_visible_$email', user.followersVisible);
      await prefs.setBool('privacy_listening_activity_$email', user.listeningActivity);
      return user;
    }
    
    final currentLinks = List<Map<String, dynamic>>.from(user.socialLinks ?? []);
    final index = currentLinks.indexWhere((l) => l['type'] == 'privacy_settings');
    
    final mergedEntry = {
      'type': 'privacy_settings',
      'profile_visible': localProfile ?? user.profileVisible,
      'playlists_visible': localPlaylists ?? user.playlistsVisible,
      'followers_visible': localFollowers ?? user.followersVisible,
      'listening_activity': localListening ?? user.listeningActivity,
    };
    
    if (index >= 0) {
      currentLinks[index] = mergedEntry;
    } else {
      currentLinks.add(mergedEntry);
    }
    
    return user.copyWith(socialLinks: currentLinks);
  }

  Future<void> _checkLoginStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      _isLoggedIn = await _authService.isLoggedIn();
      if (_isLoggedIn) {
        final rawUser = await _authService.getCurrentUser();
        if (rawUser != null) {
          _currentUser = await _mergeLocalPrivacySettings(rawUser);
        }
      }
    } catch (e) {
      debugPrint('Error checking login status: $e');
      _isLoggedIn = false;
      _currentUser = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _authService.login(
        email: email,
        password: password,
      );

      if (result.success && result.user != null) {
        _currentUser = await _mergeLocalPrivacySettings(result.user!);
        _isLoggedIn = true;
      }

      return result;
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Login failed: ${e.toString()}',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<AuthResult> register({
    required String email,
    required String username,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _authService.register(
        email: email,
        username: username,
        password: password,
      );

      if (result.success && result.user != null) {
        _currentUser = await _mergeLocalPrivacySettings(result.user!);
        _isLoggedIn = true;
      }

      return result;
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Registration failed: ${e.toString()}',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.logout();
      _currentUser = null;
      _isLoggedIn = false;
      NotificationService().cleanup();
    } catch (e) {
      debugPrint('Error during logout: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshUser() async {
    try {
      final rawUser = await _authService.getCurrentUser();
      if (rawUser != null) {
        _currentUser = await _mergeLocalPrivacySettings(rawUser);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error refreshing user: $e');
    }
  }

  /// Update user profile
  Future<void> updateProfile({
    required String username,
    String? bio,
    List<Map<String, dynamic>>? socialLinks,
    dynamic profileImageFile,
    dynamic bannerImageFile,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.updateProfile(
        username: username,
        bio: bio,
        socialLinks: socialLinks,
        profileImageFile: profileImageFile,
        bannerImageFile: bannerImageFile,
      );
      final rawUser = await _authService.getCurrentUser();
      if (rawUser != null) {
        _currentUser = await _mergeLocalPrivacySettings(rawUser);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete user account from database and log out
  Future<void> deleteAccount() async {
    final uuid = Supabase.instance.client.auth.currentUser?.id;
    if (uuid != null) {
      try {
        await _authService.deleteAccount(uuid);
      } catch (e) {
        debugPrint('Error deleting account: $e');
      }
    }
    await logout();
  }
}

