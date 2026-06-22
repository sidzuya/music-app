import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class MockAuthService {
  static final MockAuthService _instance = MockAuthService._internal();
  factory MockAuthService() => _instance;
  MockAuthService._internal();

  // Простое хранилище пользователей в памяти
  final List<UserModel> _users = [];
  UserModel? _currentUser;

  // Регистрация нового пользователя
  Future<AuthResult> register({
    required String email,
    required String username,
    required String password,
  }) async {
    try {
      // Проверяем, существует ли пользователь
      final existingUser = _users.where((user) => user.email == email.toLowerCase()).firstOrNull;
      if (existingUser != null) {
        return AuthResult(
          success: false,
          message: 'Пользователь с таким email уже существует',
        );
      }

      // Валидация
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

      // Создаём нового пользователя
      final now = DateTime.now();
      final user = UserModel(
        id: _users.length + 1,
        email: email.toLowerCase(),
        username: username,
        createdAt: now,
        updatedAt: now,
      );

      _users.add(user);
      _currentUser = user;

      // Сохраняем состояние входа
      await _saveLoginState(user);

      return AuthResult(
        success: true,
        message: 'Аккаунт успешно создан',
        user: user,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Ошибка регистрации: ${e.toString()}',
      );
    }
  }

  // Вход пользователя
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      // Валидация
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

      // Ищем пользователя
      final user = _users.where((user) => user.email == email.toLowerCase()).firstOrNull;
      if (user == null) {
        return AuthResult(
          success: false,
          message: 'Аккаунт с таким email не найден',
        );
      }

      // В реальном приложении здесь была бы проверка хэша пароля
      // Для демо просто проверяем, что пароль не пустой
      
      _currentUser = user;
      await _saveLoginState(user);

      return AuthResult(
        success: true,
        message: 'Вход выполнен успешно',
        user: user,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Ошибка входа: ${e.toString()}',
      );
    }
  }

  // Выход пользователя
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_logged_in');
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    _currentUser = null;
  }

  // Проверка, вошёл ли пользователь
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    
    if (isLoggedIn && _currentUser == null) {
      // Восстанавливаем пользователя из сохранённых данных
      final userEmail = prefs.getString('user_email');
      if (userEmail != null) {
        _currentUser = _users.where((user) => user.email == userEmail).firstOrNull;
      }
    }
    
    return isLoggedIn && _currentUser != null;
  }

  // Получить текущего пользователя
  Future<UserModel?> getCurrentUser() async {
    if (_currentUser != null) {
      return _currentUser;
    }

    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('user_email');
    
    if (userEmail != null) {
      _currentUser = _users.where((user) => user.email == userEmail).firstOrNull;
    }
    
    return _currentUser;
  }

  // Сохранить состояние входа в SharedPreferences
  Future<void> _saveLoginState(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
    await prefs.setInt('user_id', user.id!);
    await prefs.setString('user_email', user.email);
  }

  // Валидация email
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

extension FirstWhereOrNullExtension<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
