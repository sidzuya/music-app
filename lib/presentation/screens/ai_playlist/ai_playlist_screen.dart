import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/ai_playlist_composer.dart';

/// Dedicated tab that hosts the AI playlist generation experience.
///
/// The feature used to live inside [SearchScreen] but has been promoted to
/// its own bottom navigation tab so that search stays focused on genres and
/// trending tracks.
class AiPlaylistScreen extends StatelessWidget {
  const AiPlaylistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, _) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localeProvider.getString('ai_playlist_prompt_title'),
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    localeProvider.getString('ai_playlist_prompt_subtitle'),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const AiPlaylistComposer(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
