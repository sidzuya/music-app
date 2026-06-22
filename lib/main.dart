import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'data/services/supabase_service.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/music_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/providers/locale_provider.dart';
import 'presentation/providers/playlist_provider.dart';
import 'presentation/providers/recommendation_provider.dart';
import 'presentation/providers/follow_provider.dart';
import 'presentation/providers/notification_provider.dart';
import 'presentation/providers/live_room_provider.dart';
import 'presentation/providers/friend_activity_provider.dart';
import 'presentation/providers/collab_playlist_provider.dart';
import 'presentation/widgets/notification_overlay.dart';
import 'presentation/widgets/web_responsive_wrapper.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await SupabaseService.initialize();

  runApp(const MusicApp());
}

class MusicApp extends StatelessWidget {
  const MusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MusicProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => PlaylistProvider()),
        ChangeNotifierProvider(
          create: (_) => RecommendationProvider()..initialize(),
        ),
        ChangeNotifierProvider(create: (_) => FollowProvider()..refresh()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProxyProvider<MusicProvider, LiveRoomProvider>(
          create: (context) => LiveRoomProvider(Provider.of<MusicProvider>(context, listen: false)),
          update: (context, musicProvider, previous) => previous ?? LiveRoomProvider(musicProvider),
        ),
        ChangeNotifierProvider(create: (_) => FriendActivityProvider()),
        ChangeNotifierProvider(create: (_) => CollabPlaylistProvider()),
      ],
      child: Consumer2<ThemeProvider, LocaleProvider>(
        builder: (context, themeProvider, localeProvider, child) {
          return MaterialApp(
            title: 'Music App',
            theme: themeProvider.getThemeData(Brightness.light),
            darkTheme: themeProvider.getThemeData(Brightness.dark),
            themeMode: themeProvider.themeMode,
            locale: localeProvider.locale,
            debugShowCheckedModeBanner: false,
            builder: (context, child) {
              return NotificationOverlay(
                child: WebResponsiveWrapper(child: child!),
              );
            },
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // Wait for auth provider to initialize
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (authProvider.isLoggedIn) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen,
                borderRadius: BorderRadius.circular(60),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.music_note,
                color: Colors.black,
                size: 60,
              ),
            ),
            const SizedBox(height: 32),

            // App Name
            const Text(
              'MusicApp',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Tagline
            const Text(
              'Your music, your way',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 48),

            // Loading Indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
            ),
          ],
        ),
      ),
    );
  }
}
