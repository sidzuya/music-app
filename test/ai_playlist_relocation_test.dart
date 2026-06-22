import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:music_app/presentation/providers/locale_provider.dart';
import 'package:music_app/presentation/widgets/ai_playlist_composer.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'AiPlaylistComposer renders with ai_playlist_composer key',
    (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LocaleProvider>(
              create: (_) => LocaleProvider(),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: AiPlaylistComposer()),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(
        find.byKey(const Key('ai_playlist_composer')),
        findsOneWidget,
      );
    },
  );

  test(
    'SearchScreen browse content no longer embeds the AI playlist composer',
    () {
      final source = File(
        'lib/presentation/screens/search/search_screen.dart',
      ).readAsStringSync();

      expect(
        source.contains('AiPlaylistComposer'),
        isFalse,
        reason: 'SearchScreen must not reference AiPlaylistComposer widget',
      );
      expect(
        source.contains('_buildAiPlaylistComposer('),
        isFalse,
        reason:
            'The inline AI composer builder must be removed from SearchScreen',
      );
      expect(
        source.contains('_buildGeneratedPlaylist('),
        isFalse,
        reason:
            'The generated AI playlist section must be removed from SearchScreen',
      );
    },
  );

  test(
    'HomeScreen registers the AiPlaylistScreen as a bottom navigation tab',
    () {
      final source = File(
        'lib/presentation/screens/home/home_screen.dart',
      ).readAsStringSync();

      expect(
        source.contains('AiPlaylistScreen'),
        isTrue,
        reason: 'HomeScreen must import and use AiPlaylistScreen',
      );
      expect(
        RegExp(r'BottomNavigationBarItem').allMatches(source).length,
        greaterThanOrEqualTo(5),
        reason: 'Bottom navigation must expose at least five tabs',
      );
    },
  );
}
