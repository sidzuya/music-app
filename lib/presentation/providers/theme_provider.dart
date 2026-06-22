import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';

class ThemeProvider with ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  static const String _accentColorKey = 'accent_color';
  static const String _textSizeKey = 'text_size';
  static const String _showAlbumArtKey = 'show_album_art';
  static const String _animationsEnabledKey = 'animations_enabled';

  ThemeMode _themeMode = ThemeMode.dark;
  Color _accentColor = AppTheme.primaryGreen;
  double _textSize = 1.0;
  bool _showAlbumArt = true;
  bool _animationsEnabled = true;

  // Getters
  ThemeMode get themeMode => _themeMode;
  Color get accentColor => _accentColor;
  double get textSize => _textSize;
  bool get showAlbumArt => _showAlbumArt;
  bool get animationsEnabled => _animationsEnabled;

  // Available accent colors
  final Map<String, Color> _accentColors = {
    'green': AppTheme.primaryGreen,
    'blue': Colors.blue,
    'purple': Colors.purple,
    'red': Colors.red,
    'orange': Colors.orange,
  };

  Map<String, Color> get accentColors => _accentColors;

  ThemeProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load theme mode
    final themeString = prefs.getString(_themeKey) ?? 'dark';
    _themeMode = _getThemeModeFromString(themeString);
    
    // Load accent color
    final accentColorString = prefs.getString(_accentColorKey) ?? 'green';
    _accentColor = _accentColors[accentColorString] ?? AppTheme.primaryGreen;
    
    // Load text size
    _textSize = prefs.getDouble(_textSizeKey) ?? 1.0;
    
    // Load display settings
    _showAlbumArt = prefs.getBool(_showAlbumArtKey) ?? true;
    _animationsEnabled = prefs.getBool(_animationsEnabledKey) ?? true;
    
    notifyListeners();
  }

  ThemeMode _getThemeModeFromString(String theme) {
    switch (theme) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'auto':
        return ThemeMode.system;
      default:
        return ThemeMode.dark;
    }
  }

  String _getStringFromThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'auto';
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, _getStringFromThemeMode(mode));
    notifyListeners();
  }

  Future<void> setAccentColor(String colorKey) async {
    if (_accentColors.containsKey(colorKey)) {
      _accentColor = _accentColors[colorKey]!;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accentColorKey, colorKey);
      notifyListeners();
    }
  }

  Future<void> setTextSize(double size) async {
    _textSize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_textSizeKey, size);
    notifyListeners();
  }

  Future<void> setShowAlbumArt(bool show) async {
    _showAlbumArt = show;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showAlbumArtKey, show);
    notifyListeners();
  }

  Future<void> setAnimationsEnabled(bool enabled) async {
    _animationsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_animationsEnabledKey, enabled);
    notifyListeners();
  }

  String getAccentColorKey() {
    return _accentColors.entries
        .firstWhere((entry) => entry.value == _accentColor)
        .key;
  }

  // Generate theme data with current settings
  ThemeData getThemeData(Brightness brightness) {
    return AppTheme.getThemeData(brightness, _accentColor, _textSize);
  }
}
