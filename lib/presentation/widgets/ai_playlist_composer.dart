import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/ai_playlist_model.dart';
import '../../data/services/ai_settings_service.dart';
import '../../data/services/openai_playlist_service.dart';
import '../providers/locale_provider.dart';
import '../providers/music_provider.dart';
import '../providers/playlist_provider.dart';
import 'song_tile.dart';

/// Self-contained AI playlist composer: API key management, prompt input,
/// playlist generation and the "Save as playlist" flow.
///
/// Exposed via `Key('ai_playlist_composer')` for widget tests.
class AiPlaylistComposer extends StatefulWidget {
  const AiPlaylistComposer({super.key});

  @override
  State<AiPlaylistComposer> createState() => _AiPlaylistComposerState();
}

class _AiPlaylistComposerState extends State<AiPlaylistComposer> {
  final TextEditingController _aiPromptController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final AiSettingsService _aiSettingsService = AiSettingsService.instance;
  final OpenAiPlaylistService _openAiPlaylistService = OpenAiPlaylistService();

  AiGeneratedPlaylist? _generatedPlaylist;
  bool _isGeneratingAiPlaylist = false;
  bool _isSavingAiPlaylist = false;
  bool _isSavingApiKey = false;
  bool _hasConfiguredAiKey = false;
  bool _isUsingBundledAiKey = false;
  bool _obscureApiKey = true;
  String? _maskedApiKey;
  String? _aiErrorMessage;

  List<String> _getAiExamples(LocaleProvider locale) => [
    locale.getString('ai_example_1'),
    locale.getString('ai_example_2'),
    locale.getString('ai_example_3'),
  ];

  @override
  void initState() {
    super.initState();
    _loadAiSettings();
  }

  @override
  void dispose() {
    _aiPromptController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadAiSettings() async {
    final apiKey = await _aiSettingsService.getOpenAiApiKey();
    final isUsingBundledAiKey = await _aiSettingsService.isUsingBundledAiKey();
    if (!mounted) return;

    setState(() {
      _hasConfiguredAiKey = apiKey != null && apiKey.isNotEmpty;
      _isUsingBundledAiKey = isUsingBundledAiKey;
      _maskedApiKey = apiKey == null
          ? null
          : _aiSettingsService.maskKey(apiKey);
    });
  }

  Future<void> _generateAiPlaylist() async {
    final prompt = _aiPromptController.text.trim();
    if (prompt.isEmpty) return;
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    final playlistProvider = Provider.of<PlaylistProvider>(
      context,
      listen: false,
    );

    if (!_hasConfiguredAiKey && _apiKeyController.text.trim().isNotEmpty) {
      await _saveApiKey(silent: true);
    }

    if (!mounted) return;

    if (!_hasConfiguredAiKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localeProvider.getString('openai_key_missing'))),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isGeneratingAiPlaylist = true;
      _aiErrorMessage = null;
    });

    try {
      final playlist = await _openAiPlaylistService.generatePlaylist(
        prompt: prompt,
        recentSongs: musicProvider.recentlyPlayed,
        favoriteSongs: playlistProvider.favoriteSongs,
      );

      setState(() {
        _generatedPlaylist = playlist;
        _isGeneratingAiPlaylist = false;
      });
    } catch (e) {
      setState(() {
        _isGeneratingAiPlaylist = false;
        _aiErrorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _saveApiKey({bool silent = false}) async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty || _isSavingApiKey) return;

    setState(() {
      _isSavingApiKey = true;
    });

    try {
      await _aiSettingsService.saveOpenAiApiKey(apiKey);
      await _loadAiSettings();
      _apiKeyController.clear();

      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Provider.of<LocaleProvider>(
                context,
                listen: false,
              ).getString('openai_key_saved'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingApiKey = false;
        });
      }
    }
  }

  Future<void> _clearApiKey() async {
    await _aiSettingsService.clearOpenAiApiKey();
    if (!mounted) return;

    setState(() {
      _aiErrorMessage = null;
    });
    await _loadAiSettings();
  }

  Future<void> _saveGeneratedPlaylist() async {
    final generatedPlaylist = _generatedPlaylist;
    if (generatedPlaylist == null || _isSavingAiPlaylist) return;

    setState(() {
      _isSavingAiPlaylist = true;
    });

    try {
      final playlistProvider = Provider.of<PlaylistProvider>(
        context,
        listen: false,
      );

      final playlist = await playlistProvider.createPlaylist(
        generatedPlaylist.plan.playlistTitle,
        generatedPlaylist.plan.playlistDescription,
      );

      if (playlist == null) {
        throw Exception('Не удалось создать плейлист');
      }

      for (final song in generatedPlaylist.songs) {
        await playlistProvider.addSongToPlaylist(playlist.id!, song);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${generatedPlaylist.plan.playlistTitle} ${Provider.of<LocaleProvider>(context, listen: false).getString('playlist_saved')}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingAiPlaylist = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, _) {
        return Column(
          key: const Key('ai_playlist_composer'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildComposerCard(localeProvider),
            if (_generatedPlaylist != null) ...[
              const SizedBox(height: 24),
              _buildGeneratedPlaylistCard(localeProvider),
            ],
          ],
        );
      },
    );
  }

  Widget _buildComposerCard(LocaleProvider localeProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Text(
                localeProvider.getString('ai_playlist_prompt_title'),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            localeProvider.getString('ai_playlist_prompt_subtitle'),
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Text(
            localeProvider.getString('ai_playlist_steps'),
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 14),
          if (_hasConfiguredAiKey)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.verified_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${localeProvider.getString('openai_key_connected')}: ${_maskedApiKey ?? 'Gemini'}',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (!_isUsingBundledAiKey)
                    TextButton(
                      onPressed: _clearApiKey,
                      child: Text(localeProvider.getString('change')),
                    ),
                ],
              ),
            )
          else ...[
            Text(
              localeProvider.getString('openai_key_label'),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _apiKeyController,
              obscureText: _obscureApiKey,
              autocorrect: false,
              enableSuggestions: false,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: localeProvider.getString('openai_key_hint'),
                hintStyle: const TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _obscureApiKey = !_obscureApiKey;
                    });
                  },
                  icon: Icon(
                    _obscureApiKey ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isSavingApiKey ? null : _saveApiKey,
                icon: _isSavingApiKey
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.key),
                label: Text(localeProvider.getString('save_openai_key')),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            localeProvider.getString('ai_playlist_where_to_type'),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _getAiExamples(context.read<LocaleProvider>())
                .map(
                  (example) => ActionChip(
                    label: Text(example),
                    onPressed: () {
                      _aiPromptController.text = example;
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _aiPromptController,
            minLines: 2,
            maxLines: 4,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _generateAiPlaylist(),
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: localeProvider.getString('ai_playlist_prompt_hint'),
              hintStyle: const TextStyle(color: AppTheme.textSecondary),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!_hasConfiguredAiKey)
            Text(
              localeProvider.getString('openai_key_missing'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            )
          else if (_aiErrorMessage != null)
            Text(
              _aiErrorMessage!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isGeneratingAiPlaylist ? null : _generateAiPlaylist,
              icon: _isGeneratingAiPlaylist
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                _isGeneratingAiPlaylist
                    ? localeProvider.getString('generating_ai_playlist')
                    : localeProvider.getString('generate_ai_playlist'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratedPlaylistCard(LocaleProvider localeProvider) {
    final playlist = _generatedPlaylist!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localeProvider.getString('ai_playlist_results'),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            playlist.plan.playlistTitle,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            playlist.plan.playlistDescription,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          if (playlist.plan.preferredGenres.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: playlist.plan.preferredGenres
                  .take(3)
                  .map(
                    (genre) => Chip(
                      label: Text(genre),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.12),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Provider.of<MusicProvider>(
                        context,
                        listen: false,
                      ).playPlaylist(playlist.songs, 0);
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: Text(localeProvider.getString('play_ai_playlist')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSavingAiPlaylist
                        ? null
                        : _saveGeneratedPlaylist,
                    icon: _isSavingAiPlaylist
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.playlist_add),
                    label: Text(localeProvider.getString('save_ai_playlist')),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...playlist.songs.map(
            (song) => SongTile(
              song: song,
              onTap: () {
                Provider.of<MusicProvider>(
                  context,
                  listen: false,
                ).playSong(song);
              },
            ),
          ),
        ],
      ),
    );
  }
}
