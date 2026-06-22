class AppConstants {
  // App Information
  static const String appName = 'MusicApp';
  static const String appVersion = '1.0.0';
  static const String webAppUrl = String.fromEnvironment(
    'WEB_APP_URL',
    defaultValue: 'https://krysa-music.up.railway.app',
  );

  // Music Catalog API
  static const String audiusBaseUrl = 'https://api.audius.co/v1';
  static const String audiusAppName = 'music_app';
  static const String audiusBearerToken = String.fromEnvironment(
    'AUDIUS_BEARER_TOKEN',
    defaultValue: '',
  );
  static const String googleAiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';
  static const String googleAiApiKey = String.fromEnvironment(
    'GOOGLE_AI_API_KEY',
    defaultValue: String.fromEnvironment(
      'GEMINI_API_KEY',
      defaultValue: 'AIzaSyAsR3rTfhSiifpJpM0MYWdw2uPULvCflZU',
    ),
  );
  static const String googleAiPlaylistModel = String.fromEnvironment(
    'GOOGLE_AI_MODEL',
    defaultValue: String.fromEnvironment(
      'GEMINI_PLAYLIST_MODEL',
      defaultValue: 'gemini-2.5-flash',
    ),
  );
  static const String googleAiFallbackPlaylistModel = String.fromEnvironment(
    'GOOGLE_AI_FALLBACK_MODEL',
    defaultValue: 'gemini-2.5-flash-lite',
  );

  // Resend Email Settings
  static const String resendApiKey = String.fromEnvironment(
    'RESEND_API_KEY',
    defaultValue: '',
  );
  static const String senderEmail = String.fromEnvironment(
    'SENDER_EMAIL',
    defaultValue: 'onboarding@resend.dev',
  );

  // Database
  static const String databaseName = 'music_app.db';
  static const int databaseVersion = 1;

  // Tables
  static const String usersTable = 'users';
  static const String songsTable = 'songs';
  static const String playlistsTable = 'playlists';
  static const String playlistSongsTable = 'playlist_songs';
  static const String favoritesTable = 'favorites';

  // Shared Preferences Keys
  static const String isLoggedInKey = 'is_logged_in';
  static const String userIdKey = 'user_id';
  static const String userEmailKey = 'user_email';
  static const String themeKey = 'theme_mode';

  // API Endpoints (for future use)
  static const String baseUrl = 'https://api.example.com';
  static const String loginEndpoint = '/auth/login';
  static const String registerEndpoint = '/auth/register';
  static const String songsEndpoint = '/songs';

  // Audio Settings
  static const Duration seekDuration = Duration(seconds: 10);
  static const double defaultVolume = 0.7;

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double borderRadius = 8.0;
  static const double cardElevation = 2.0;

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);

  // Validation
  static const int minPasswordLength = 6;
  static const int maxUsernameLength = 30;

  // Sample Data (for development)
  static const List<Map<String, String>> sampleSongs = [
    {
      'title': 'Blinding Lights',
      'artist': 'The Weeknd',
      'album': 'After Hours',
      'duration': '3:20',
      'image': 'https://example.com/blinding-lights.jpg',
    },
    {
      'title': 'Watermelon Sugar',
      'artist': 'Harry Styles',
      'album': 'Fine Line',
      'duration': '2:54',
      'image': 'https://example.com/watermelon-sugar.jpg',
    },
    {
      'title': 'Levitating',
      'artist': 'Dua Lipa',
      'album': 'Future Nostalgia',
      'duration': '3:23',
      'image': 'https://example.com/levitating.jpg',
    },
  ];
}
