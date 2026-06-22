import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

/// Service for authentication with Supabase
class SupabaseAuthService {
  static SupabaseAuthService? _instance;
  
  SupabaseAuthService._();
  
  static SupabaseAuthService get instance {
    _instance ??= SupabaseAuthService._();
    return _instance!;
  }

  SupabaseClient get _client => Supabase.instance.client;

  /// Register a new user
  Future<AuthResult> register({
    required String email,
    required String username,
    required String password,
  }) async {
    try {
      // Validate input
      if (!_isValidEmail(email)) {
        return AuthResult(
          success: false,
          message: 'Введите корректный email адрес',
        );
      }

      if (password.length < 6) {
        return AuthResult(
          success: false,
          message: 'Пароль должен содержать минимум 6 символов',
        );
      }

      if (username.isEmpty || username.length > 30) {
        return AuthResult(
          success: false,
          message: 'Имя пользователя должно быть от 1 до 30 символов',
        );
      }

      // Register with Supabase Auth (username passed in metadata for trigger)
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'username': username}, // This will be used by the trigger
      );

      if (response.user == null) {
        return AuthResult(
          success: false,
          message: 'Ошибка регистрации. Попробуйте позже.',
        );
      }

      // Profile is normally created by a Supabase trigger, but we also
      // upsert here defensively so login never breaks if the trigger is
      // missing or fired before the auth user was committed.
      final now = DateTime.now();
      await _ensureProfileRow(
        userId: response.user!.id,
        email: email.toLowerCase(),
        username: username,
        createdAt: now,
      );

      final user = UserModel(
        id: response.user!.id.hashCode,
        email: email.toLowerCase(),
        username: username,
        createdAt: now,
        updatedAt: now,
      );

      return AuthResult(
        success: true,
        message: 'Аккаунт успешно создан',
        user: user,
      );
    } on AuthException catch (e) {
      return AuthResult(
        success: false,
        message: _getAuthErrorMessage(e.message),
      );
    } catch (e) {
      print('Registration error: $e');
      return AuthResult(
        success: false,
        message: 'Ошибка регистрации: ${e.toString()}',
      );
    }
  }

  /// Login user
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      if (!_isValidEmail(email)) {
        return AuthResult(
          success: false,
          message: 'Введите корректный email адрес',
        );
      }

      if (password.isEmpty) {
        return AuthResult(
          success: false,
          message: 'Введите пароль',
        );
      }

      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        return AuthResult(
          success: false,
          message: 'Неверный email или пароль',
        );
      }

      // Get user profile from database. If the row is missing (e.g. the
      // signup trigger never fired) self-heal by creating it from the auth
      // user metadata instead of failing the login.
      Map<String, dynamic>? profileData = await _client
          .from('profiles')
          .select()
          .eq('id', response.user!.id)
          .maybeSingle();

      if (profileData == null) {
        final fallbackUsername =
            (response.user!.userMetadata?['username'] as String?) ??
                email.split('@').first;
        profileData = await _ensureProfileRow(
          userId: response.user!.id,
          email: email.toLowerCase(),
          username: fallbackUsername,
          createdAt: DateTime.now(),
        );
      }

      final user = UserModel(
        id: response.user!.id.hashCode,
        email: (profileData?['email'] as String?) ?? email,
        username: (profileData?['username'] as String?) ?? 'User',
        profileImage: profileData?['profile_image'] as String?,
        createdAt: profileData?['created_at'] != null
            ? DateTime.parse(profileData!['created_at'] as String)
            : DateTime.now(),
        updatedAt: profileData?['updated_at'] != null
            ? DateTime.parse(profileData!['updated_at'] as String)
            : DateTime.now(),
      );

      return AuthResult(
        success: true,
        message: 'Вход выполнен успешно',
        user: user,
      );
    } on AuthException catch (e) {
      return AuthResult(
        success: false,
        message: _getAuthErrorMessage(e.message),
      );
    } catch (e) {
      print('Login error: $e');
      return AuthResult(
        success: false,
        message: 'Ошибка входа: ${e.toString()}',
      );
    }
  }

  /// Logout user
  Future<void> logout() async {
    await _client.auth.signOut();
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final session = _client.auth.currentSession;
    return session != null;
  }

  /// Get current user
  Future<UserModel?> getCurrentUser() async {
    try {
      final session = _client.auth.currentSession;
      if (session == null) return null;

      final userId = session.user.id;

      Map<String, dynamic>? profileData = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (profileData == null) {
        final fallbackUsername =
            (session.user.userMetadata?['username'] as String?) ??
                session.user.email?.split('@').first ??
                'User';
        profileData = await _ensureProfileRow(
          userId: userId,
          email: session.user.email ?? '',
          username: fallbackUsername,
          createdAt: DateTime.now(),
        );
      }

      return UserModel(
        id: userId.hashCode,
        email: (profileData?['email'] as String?) ??
            session.user.email ?? '',
        username: (profileData?['username'] as String?) ?? 'User',
        profileImage: profileData?['profile_image'] as String?,
        bannerImage: profileData?['banner_image'] as String?,
        bio: profileData?['bio'] as String?,
        socialLinks: profileData?['social_links'] != null
            ? List<Map<String, dynamic>>.from(profileData!['social_links'])
            : null,
        createdAt: profileData?['created_at'] != null
            ? DateTime.parse(profileData!['created_at'] as String)
            : DateTime.now(),
        updatedAt: profileData?['updated_at'] != null
            ? DateTime.parse(profileData!['updated_at'] as String)
            : DateTime.now(),
      );
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  /// Upsert a row into `profiles` so login/lookup never fails because of a
  /// missing trigger. Returns the persisted row (or null if upsert/select
  /// fails for any reason — the caller will then fall back to in-memory data).
  Future<Map<String, dynamic>?> _ensureProfileRow({
    required String userId,
    required String email,
    required String username,
    required DateTime createdAt,
  }) async {
    try {
      final nowIso = DateTime.now().toIso8601String();
      final payload = <String, dynamic>{
        'id': userId,
        'email': email,
        'username': username,
        'created_at': createdAt.toIso8601String(),
        'updated_at': nowIso,
      };

      final inserted = await _client
          .from('profiles')
          .upsert(payload, onConflict: 'id')
          .select()
          .maybeSingle();

      return inserted;
    } catch (e) {
      print('Failed to ensure profile row for $userId: $e');
      return null;
    }
  }

  /// Validate email format
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// Update user profile (username and/or image)
  Future<void> updateProfile({
    required String username,
    String? bio,
    List<Map<String, dynamic>>? socialLinks,
    File? profileImageFile,
    File? bannerImageFile,
  }) async {
    final session = _client.auth.currentSession;
    if (session == null) {
      throw Exception('Пользователь не авторизован');
    }

    if (username.isEmpty || username.length > 30) {
      throw Exception('Имя пользователя должно быть от 1 до 30 символов');
    }

    final updates = <String, dynamic>{
      'username': username,
      'updated_at': DateTime.now().toIso8601String(),
      'bio': bio,
      'social_links': socialLinks,
    };

    if (profileImageFile != null) {
      final imageUrl = await _uploadImage(profileImageFile, session.user.id, 'avatars');
      updates['profile_image'] = imageUrl;
    }

    if (bannerImageFile != null) {
      final imageUrl = await _uploadImage(bannerImageFile, session.user.id, 'banners');
      updates['banner_image'] = imageUrl;
    }

    try {
      await _client
          .from('profiles')
          .update(updates)
          .eq('id', session.user.id);
    } on PostgrestException catch (e) {
      // The `social_links` column may not exist in the database yet (the
      // `artist_profile_update.sql` migration has not been applied). In that
      // case retry the update without it so the rest of the profile still
      // saves instead of throwing. Privacy still works locally via
      // SharedPreferences (see AuthProvider._mergeLocalPrivacySettings).
      final mentionsSocialLinks =
          e.message.toLowerCase().contains('social_links');
      if (!mentionsSocialLinks) rethrow;
      updates.remove('social_links');
      await _client
          .from('profiles')
          .update(updates)
          .eq('id', session.user.id);
    }
  }

  /// Upload image to Storage (for profile and banner images)
  Future<String> _uploadImage(File imageFile, String userId, String folder) async {
    try {
      final fileExt = imageFile.path.split('.').last;
      final fileName = '$userId/$folder/${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      
      await _client.storage
          .from('profiles') // Assuming a generic 'profiles' bucket for all user-related images
          .upload(fileName, imageFile, fileOptions: const FileOptions(upsert: true));
          
      final imageUrl = _client.storage
          .from('profiles')
          .getPublicUrl(fileName);
          
      return imageUrl;
    } catch (e) {
      print('Error uploading image to $folder: $e');
      throw Exception('Не удалось загрузить изображение: $e');
    }
  }

  /// Delete profile row from database
  Future<void> deleteAccount(String userId) async {
    try {
      await _client.from('profiles').delete().eq('id', userId);
    } catch (e) {
      print('Failed to delete profile row for user $userId: $e');
    }
  }

  /// Convert Supabase error messages to user-friendly Russian messages
  String _getAuthErrorMessage(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'Неверный email или пароль';
    }
    if (message.contains('User already registered')) {
      return 'Пользователь с таким email уже существует';
    }
    if (message.contains('Email not confirmed')) {
      return 'Email не подтверждён. Проверьте почту.';
    }
    if (message.contains('Password')) {
      return 'Пароль должен содержать минимум 6 символов';
    }
    return message;
  }
}

class AuthResult {
  final bool success;
  final String message;
  final UserModel? user;

  AuthResult({
    required this.success,
    required this.message,
    this.user,
  });
}
