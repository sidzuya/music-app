import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'database_service.dart';
import '../../core/constants/app_constants.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final DatabaseService _databaseService = DatabaseService();

  // Register a new user
  Future<AuthResult> register({
    required String email,
    required String username,
    required String password,
  }) async {
    try {
      // Check if user already exists
      final existingUser = await _databaseService.getUserByEmail(email);
      if (existingUser != null) {
        return AuthResult(
          success: false,
          message: 'User with this email already exists',
        );
      }

      // Validate input
      if (!_isValidEmail(email)) {
        return AuthResult(
          success: false,
          message: 'Please enter a valid email address',
        );
      }

      if (password.length < AppConstants.minPasswordLength) {
        return AuthResult(
          success: false,
          message: 'Password must be at least ${AppConstants.minPasswordLength} characters long',
        );
      }

      if (username.isEmpty || username.length > AppConstants.maxUsernameLength) {
        return AuthResult(
          success: false,
          message: 'Username must be between 1 and ${AppConstants.maxUsernameLength} characters',
        );
      }

      // Create new user
      final now = DateTime.now();
      final user = UserModel(
        email: email.toLowerCase(),
        username: username,
        createdAt: now,
        updatedAt: now,
      );

      final userId = await _databaseService.insertUser(user);
      final createdUser = user.copyWith(id: userId);

      // Save login state
      await _saveLoginState(createdUser);

      return AuthResult(
        success: true,
        message: 'Account created successfully',
        user: createdUser,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Registration failed: ${e.toString()}',
      );
    }
  }

  // Login user
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      // Validate input
      if (!_isValidEmail(email)) {
        return AuthResult(
          success: false,
          message: 'Please enter a valid email address',
        );
      }

      if (password.isEmpty) {
        return AuthResult(
          success: false,
          message: 'Please enter your password',
        );
      }

      // Check if user exists
      final user = await _databaseService.getUserByEmail(email.toLowerCase());
      if (user == null) {
        return AuthResult(
          success: false,
          message: 'No account found with this email',
        );
      }

      // In a real app, you would verify the password hash here
      // For this demo, we'll just check if the password is not empty
      
      // Save login state
      await _saveLoginState(user);

      return AuthResult(
        success: true,
        message: 'Login successful',
        user: user,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Login failed: ${e.toString()}',
      );
    }
  }

  // Logout user
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.isLoggedInKey);
    await prefs.remove(AppConstants.userIdKey);
    await prefs.remove(AppConstants.userEmailKey);
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.isLoggedInKey) ?? false;
  }

  // Get current user
  Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt(AppConstants.userIdKey);
    
    if (userId != null) {
      return await _databaseService.getUserById(userId);
    }
    
    return null;
  }

  // Save login state to SharedPreferences
  Future<void> _saveLoginState(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.isLoggedInKey, true);
    await prefs.setInt(AppConstants.userIdKey, user.id!);
    await prefs.setString(AppConstants.userEmailKey, user.email);
  }

  // Validate email format
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
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
