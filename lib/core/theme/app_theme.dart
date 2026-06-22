import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Base colors
  static const Color primaryGreen = Color(0xFF1DB954);
  static const Color darkBackground = Color(0xFF121212);
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFF1E1E1E);
  static const Color lightCardBackground = Color(0xFFF5F5F5);
  static const Color surfaceColor = Color(0xFF282828);
  static const Color lightSurfaceColor = Color(0xFFE0E0E0);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color lightTextSecondary = Color(0xFF666666);
  static const Color textTertiary = Color(0xFF535353);
  static const Color lightTextTertiary = Color(0xFF999999);
  static const Color errorColor = Color(0xFFE22134);

  static ThemeData getThemeData(Brightness brightness, Color accentColor, double textScale) {
    final isDark = brightness == Brightness.dark;
    
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: accentColor,
      scaffoldBackgroundColor: isDark ? darkBackground : lightBackground,
      
      // Color scheme
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: accentColor,
        onPrimary: isDark ? Colors.black : Colors.white,
        secondary: accentColor,
        onSecondary: isDark ? Colors.black : Colors.white,
        surface: isDark ? surfaceColor : lightSurfaceColor,
        onSurface: isDark ? textPrimary : lightTextPrimary,
        background: isDark ? darkBackground : lightBackground,
        onBackground: isDark ? textPrimary : lightTextPrimary,
        error: errorColor,
        onError: Colors.white,
      ),
      
      // Text theme with scaling
      textTheme: GoogleFonts.interTextTheme(
        TextTheme(
          displayLarge: TextStyle(
            color: isDark ? textPrimary : lightTextPrimary,
            fontSize: 32 * textScale,
            fontWeight: FontWeight.bold,
          ),
          displayMedium: TextStyle(
            color: isDark ? textPrimary : lightTextPrimary,
            fontSize: 28 * textScale,
            fontWeight: FontWeight.bold,
          ),
          displaySmall: TextStyle(
            color: isDark ? textPrimary : lightTextPrimary,
            fontSize: 24 * textScale,
            fontWeight: FontWeight.bold,
          ),
          headlineLarge: TextStyle(
            color: isDark ? textPrimary : lightTextPrimary,
            fontSize: 22 * textScale,
            fontWeight: FontWeight.w600,
          ),
          headlineMedium: TextStyle(
            color: isDark ? textPrimary : lightTextPrimary,
            fontSize: 20 * textScale,
            fontWeight: FontWeight.w600,
          ),
          headlineSmall: TextStyle(
            color: isDark ? textPrimary : lightTextPrimary,
            fontSize: 18 * textScale,
            fontWeight: FontWeight.w600,
          ),
          titleLarge: TextStyle(
            color: isDark ? textPrimary : lightTextPrimary,
            fontSize: 16 * textScale,
            fontWeight: FontWeight.w500,
          ),
          titleMedium: TextStyle(
            color: isDark ? textSecondary : lightTextSecondary,
            fontSize: 14 * textScale,
            fontWeight: FontWeight.w500,
          ),
          titleSmall: TextStyle(
            color: isDark ? textSecondary : lightTextSecondary,
            fontSize: 12 * textScale,
            fontWeight: FontWeight.w500,
          ),
          bodyLarge: TextStyle(
            color: isDark ? textPrimary : lightTextPrimary,
            fontSize: 16 * textScale,
            fontWeight: FontWeight.normal,
          ),
          bodyMedium: TextStyle(
            color: isDark ? textSecondary : lightTextSecondary,
            fontSize: 14 * textScale,
            fontWeight: FontWeight.normal,
          ),
          bodySmall: TextStyle(
            color: isDark ? textTertiary : lightTextTertiary,
            fontSize: 12 * textScale,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),
      
      // App bar theme
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? darkBackground : lightBackground,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: isDark ? textPrimary : lightTextPrimary,
          fontSize: 20 * textScale,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: isDark ? textPrimary : lightTextPrimary),
      ),
      
      // Bottom navigation bar theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? cardBackground : lightCardBackground,
        selectedItemColor: accentColor,
        unselectedItemColor: isDark ? textSecondary : lightTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      
      // Card theme
      cardTheme: CardThemeData(
        color: isDark ? cardBackground : lightCardBackground,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      
      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: isDark ? Colors.black : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        ),
      ),
      
      // Text button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? textSecondary : lightTextSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      
      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? surfaceColor : lightSurfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: accentColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        hintStyle: TextStyle(color: isDark ? textTertiary : lightTextTertiary),
        labelStyle: TextStyle(color: isDark ? textSecondary : lightTextSecondary),
      ),
      
      // Icon theme
      iconTheme: IconThemeData(
        color: isDark ? textSecondary : lightTextSecondary,
        size: 24,
      ),
      
      // Slider theme
      sliderTheme: SliderThemeData(
        activeTrackColor: accentColor,
        inactiveTrackColor: isDark ? textTertiary : lightTextTertiary,
        thumbColor: accentColor,
        overlayColor: accentColor.withOpacity(0.16),
      ),
    );
  }

  // Backward compatibility
  static ThemeData get darkTheme => getThemeData(Brightness.dark, primaryGreen, 1.0);
  static ThemeData get lightTheme => getThemeData(Brightness.light, primaryGreen, 1.0);
}
