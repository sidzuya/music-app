import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/theme_provider.dart';
import '../../providers/locale_provider.dart';

class DisplaySettingsScreen extends StatefulWidget {
  const DisplaySettingsScreen({super.key});

  @override
  State<DisplaySettingsScreen> createState() => _DisplaySettingsScreenState();
}

class _DisplaySettingsScreenState extends State<DisplaySettingsScreen> {

  final List<Map<String, dynamic>> _themes = [
    {'value': 'dark', 'title': 'Тёмная', 'subtitle': 'Рекомендуется'},
    {'value': 'light', 'title': 'Светлая', 'subtitle': 'Классическая'},
    {'value': 'auto', 'title': 'Авто', 'subtitle': 'Следует системе'},
  ];

  final List<Map<String, dynamic>> _languages = [
    {'value': 'ru', 'title': 'Русский', 'flag': '🇷🇺'},
    {'value': 'en', 'title': 'English', 'flag': '🇺🇸'},
    {'value': 'es', 'title': 'Español', 'flag': '🇪🇸'},
    {'value': 'fr', 'title': 'Français', 'flag': '🇫🇷'},
  ];

  final List<Map<String, dynamic>> _accentColors = [
    {'value': 'green', 'title': 'Зелёный', 'color': AppTheme.primaryGreen},
    {'value': 'blue', 'title': 'Синий', 'color': Colors.blue},
    {'value': 'purple', 'title': 'Фиолетовый', 'color': Colors.purple},
    {'value': 'red', 'title': 'Красный', 'color': Colors.red},
    {'value': 'orange', 'title': 'Оранжевый', 'color': Colors.orange},
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LocaleProvider>(
      builder: (context, themeProvider, localeProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(localeProvider.getString('display')),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Theme Section
              _buildSectionHeader(localeProvider.getString('theme')),
              const SizedBox(height: 16),
              _buildThemeOption('dark', localeProvider.getString('dark_theme'), localeProvider.getString('recommended'), themeProvider, ThemeMode.dark),
              _buildThemeOption('light', localeProvider.getString('light_theme'), localeProvider.getString('classic'), themeProvider, ThemeMode.light),
              _buildThemeOption('auto', localeProvider.getString('auto_theme'), localeProvider.getString('follows_system'), themeProvider, ThemeMode.system),
              const SizedBox(height: 32),

              // Accent Color Section
              _buildSectionHeader(localeProvider.getString('accent_color')),
              const SizedBox(height: 16),
              _buildAccentColorGrid(themeProvider),
              const SizedBox(height: 32),

              // Language Section
              _buildSectionHeader(localeProvider.getString('language')),
              const SizedBox(height: 16),
              ...localeProvider.supportedLanguages.map((language) => 
                _buildLanguageOption(language, localeProvider)),
              const SizedBox(height: 32),

              // Text Size Section
              _buildSectionHeader(localeProvider.getString('text_size')),
              const SizedBox(height: 16),
              _buildTextSizeSlider(themeProvider, localeProvider),
              const SizedBox(height: 32),

              // Display Options
              _buildSectionHeader(localeProvider.getString('display')),
              const SizedBox(height: 16),
              _buildSwitchTile(
                localeProvider.getString('show_album_art'),
                localeProvider.getString('show_album_art_subtitle'),
                themeProvider.showAlbumArt,
                (value) => themeProvider.setShowAlbumArt(value),
              ),
              _buildSwitchTile(
                localeProvider.getString('animations'),
                localeProvider.getString('animations_subtitle'),
                themeProvider.animationsEnabled,
                (value) => themeProvider.setAnimationsEnabled(value),
              ),
              const SizedBox(height: 32),

              // Preview Section
              _buildSectionHeader(localeProvider.getString('preview')),
              const SizedBox(height: 16),
              _buildPreviewCard(themeProvider, localeProvider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildThemeOption(String value, String title, String subtitle, ThemeProvider themeProvider, ThemeMode themeMode) {
    return RadioListTile<ThemeMode>(
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      value: themeMode,
      groupValue: themeProvider.themeMode,
      activeColor: themeProvider.accentColor,
      onChanged: (value) {
        if (value != null) {
          themeProvider.setThemeMode(value);
        }
      },
    );
  }

  Widget _buildLanguageOption(Map<String, String> language, LocaleProvider localeProvider) {
    return RadioListTile<String>(
      title: Row(
        children: [
          Text(
            language['flag']!,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 12),
          Text(
            language['name']!,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
      value: language['code']!,
      groupValue: localeProvider.locale.languageCode,
      activeColor: Theme.of(context).colorScheme.primary,
      onChanged: (value) {
        if (value != null) {
          localeProvider.setLocale(value);
        }
      },
    );
  }

  Widget _buildAccentColorGrid(ThemeProvider themeProvider) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: themeProvider.accentColors.length,
      itemBuilder: (context, index) {
        final colorEntry = themeProvider.accentColors.entries.elementAt(index);
        final isSelected = themeProvider.accentColor == colorEntry.value;
        
        return GestureDetector(
          onTap: () {
            themeProvider.setAccentColor(colorEntry.key);
          },
          child: Container(
            decoration: BoxDecoration(
              color: colorEntry.value,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2)
                  : null,
            ),
            child: isSelected
                ? const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 24,
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildTextSizeSlider(ThemeProvider themeProvider, LocaleProvider localeProvider) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'А',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
            ),
            Text(
              localeProvider.getString('sample_text'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 16 * themeProvider.textSize,
              ),
            ),
            Text(
              'А',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Slider(
          value: themeProvider.textSize,
          min: 0.8,
          max: 1.4,
          divisions: 6,
          activeColor: themeProvider.accentColor,
          onChanged: (value) {
            themeProvider.setTextSize(value);
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              localeProvider.getString('small'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 12 * themeProvider.textSize,
              ),
            ),
            Text(
              localeProvider.getString('large'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 12 * themeProvider.textSize,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      value: value,
      onChanged: onChanged,
      activeColor: Theme.of(context).colorScheme.primary,
    );
  }

  Widget _buildPreviewCard(ThemeProvider themeProvider, LocaleProvider localeProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (themeProvider.showAlbumArt)
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: themeProvider.accentColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.music_note,
                    color: Colors.white,
                  ),
                ),
              if (themeProvider.showAlbumArt) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localeProvider.getString('sample_song'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 16 * themeProvider.textSize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      localeProvider.getString('sample_artist'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14 * themeProvider.textSize,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.favorite,
                color: themeProvider.accentColor,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.3,
              child: Container(
                decoration: BoxDecoration(
                  color: themeProvider.accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
