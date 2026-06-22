import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/artist_application_model.dart';
import '../../../data/models/catalog_song_model.dart';
import '../../../data/models/report_model.dart';
import '../../../data/services/artist_application_service.dart';
import '../../../data/services/reports_service.dart';
import '../../../data/services/songs_catalog_service.dart';
import '../../../data/services/email_service.dart';
import '../admin/admin_songs_screen.dart';
import '../admin/admin_upload_screen.dart';

/// Moderator hub: queues + catalog manager.
class ModeratorPanelScreen extends StatelessWidget {
  const ModeratorPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Панель модератора'),
          bottom: const TabBar(
            isScrollable: false,
            tabs: [
              Tab(icon: Icon(Icons.verified_user_outlined), text: 'Заявки'),
              Tab(icon: Icon(Icons.queue_music_outlined), text: 'Треки'),
              Tab(icon: Icon(Icons.library_music_outlined), text: 'Песни'),
              Tab(icon: Icon(Icons.upload_file_outlined), text: 'Загрузка'),
              Tab(icon: Icon(Icons.flag_outlined), text: 'Жалобы'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ApplicationsQueue(),
            _SongsQueue(),
            AdminSongsScreen(),
            AdminUploadScreen(),
            _ReportsQueue(),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Applications queue
// ============================================================================
class _ApplicationsQueue extends StatefulWidget {
  const _ApplicationsQueue();

  @override
  State<_ApplicationsQueue> createState() => _ApplicationsQueueState();
}

class _ApplicationsQueueState extends State<_ApplicationsQueue> {
  late Future<List<ArtistApplication>> _future;

  @override
  void initState() {
    super.initState();
    _future = ArtistApplicationService.queue();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = ArtistApplicationService.queue();
    });
    await _future;
  }

  Future<void> _approve(ArtistApplication app) async {
    final note = await _askNote(context, 'Комментарий (необязательно)');
    if (note == null) return; // cancelled
    try {
      await ArtistApplicationService.approve(app.id, note: note.isEmpty ? null : note);
      if (!mounted) return;
      _toast('Заявка одобрена. Роль выдана.');
      
      // Trigger approval email
      debugPrint('Approval: app.userEmail=${app.userEmail}, artistName=${app.artistName}');
      if (app.userEmail != null && app.userEmail!.isNotEmpty) {
        debugPrint('Sending approval email to ${app.userEmail}');
        final success = await EmailService.sendArtistApprovalEmail(
          recipientEmail: app.userEmail!,
          artistName: app.artistName,
          note: note.isEmpty ? null : note,
        );
        if (success) {
          _toast('Письмо об одобрении отправлено на ${app.userEmail}');
        } else {
          _toast('Ошибка отправки письма об одобрении на ${app.userEmail}', error: true);
        }
      } else {
        _toast('Не удалось отправить письмо: email пользователя отсутствует', error: true);
        debugPrint('Cannot send approval email: applicant userEmail is null or empty');
      }
      
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _toast('Ошибка: $e', error: true);
    }
  }

  Future<void> _reject(ArtistApplication app) async {
    final note = await _askNote(context, 'Причина отклонения (обязательно)',
        required: true);
    if (note == null || note.isEmpty) return;
    try {
      await ArtistApplicationService.reject(app.id, note);
      if (!mounted) return;
      _toast('Заявка отклонена.');

      // Trigger rejection email
      debugPrint('Rejection: app.userEmail=${app.userEmail}, artistName=${app.artistName}, reason=$note');
      if (app.userEmail != null && app.userEmail!.isNotEmpty) {
        debugPrint('Sending rejection email to ${app.userEmail}');
        final success = await EmailService.sendArtistRejectionEmail(
          recipientEmail: app.userEmail!,
          artistName: app.artistName,
          reason: note,
        );
        if (success) {
          _toast('Письмо об отклонении отправлено на ${app.userEmail}');
        } else {
          _toast('Ошибка отправки письма об отклонении на ${app.userEmail}', error: true);
        }
      } else {
        _toast('Не удалось отправить письмо: email пользователя отсутствует', error: true);
        debugPrint('Cannot send rejection email: applicant userEmail is null or empty');
      }

      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _toast('Ошибка: $e', error: true);
    }
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppTheme.errorColor : null));
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<ArtistApplication>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('Ошибка: ${snap.error}'))]);
          }
          final apps = snap.data ?? const [];
          if (apps.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 80),
              Center(child: Text('Нет заявок на рассмотрении')),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: apps.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final a = apps[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.artistName,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      if (a.username != null || a.userEmail != null)
                        Text(
                          [a.username, a.userEmail]
                              .whereType<String>()
                              .join(' · '),
                          style: const TextStyle(fontSize: 12),
                        ),
                      const SizedBox(height: 8),
                      if (a.bio?.isNotEmpty == true) Text('О себе: ${a.bio}'),
                      if (a.links?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text('Ссылки: ${a.links}'),
                      ],
                      const SizedBox(height: 4),
                      Text('Причина: ${a.reason}'),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _reject(a),
                            icon: const Icon(Icons.close),
                            label: const Text('Отклонить'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () => _approve(a),
                            icon: const Icon(Icons.check),
                            label: const Text('Одобрить'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================================
// Songs queue (premoderation)
// ============================================================================
class _SongsQueue extends StatefulWidget {
  const _SongsQueue();

  @override
  State<_SongsQueue> createState() => _SongsQueueState();
}

class _SongsQueueState extends State<_SongsQueue> {
  late Future<List<CatalogSong>> _future;

  @override
  void initState() {
    super.initState();
    _future = SongsCatalogService.pending();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = SongsCatalogService.pending();
    });
    await _future;
  }

  Future<void> _approve(CatalogSong s) async {
    try {
      await SongsCatalogService.approve(s.id);
      if (!mounted) return;
      _toast('Трек одобрен');
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _toast('Ошибка: $e', error: true);
    }
  }

  Future<void> _reject(CatalogSong s) async {
    final note = await _askNote(context, 'Причина отклонения (обязательно)',
        required: true);
    if (note == null || note.isEmpty) return;
    try {
      await SongsCatalogService.reject(s.id, note);
      if (!mounted) return;
      _toast('Трек отклонён');
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _toast('Ошибка: $e', error: true);
    }
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppTheme.errorColor : null));
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<CatalogSong>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('Ошибка: ${snap.error}'))]);
          }
          final songs = snap.data ?? const [];
          if (songs.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 80),
              Center(child: Text('Нет треков на модерации')),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: songs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final s = songs[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        if (s.coverUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(s.coverUrl!,
                                width: 56, height: 56, fit: BoxFit.cover),
                          )
                        else
                          const Icon(Icons.music_note, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              Text(s.artist),
                              if (s.album?.isNotEmpty == true)
                                Text('Альбом: ${s.album}',
                                    style: const TextStyle(fontSize: 12)),
                              if (s.genre?.isNotEmpty == true)
                                Text('Жанр: ${s.genre}',
                                    style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      SelectableText('Аудио: ${s.audioUrl}',
                          style: const TextStyle(fontSize: 11)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _reject(s),
                            icon: const Icon(Icons.close),
                            label: const Text('Отклонить'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () => _approve(s),
                            icon: const Icon(Icons.check),
                            label: const Text('Одобрить'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================================
// Reports queue
// ============================================================================
class _ReportsQueue extends StatefulWidget {
  const _ReportsQueue();

  @override
  State<_ReportsQueue> createState() => _ReportsQueueState();
}

class _ReportsQueueState extends State<_ReportsQueue> {
  late Future<List<ReportItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = ReportsService.queue();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = ReportsService.queue();
    });
    await _future;
  }

  Future<void> _setStatus(ReportItem r, ReportStatus newStatus) async {
    final note = await _askNote(context, 'Комментарий (необязательно)');
    if (note == null) return;
    try {
      await ReportsService.setStatus(r.id, newStatus,
          note: note.isEmpty ? null : note);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(newStatus == ReportStatus.resolved
                ? 'Жалоба обработана'
                : 'Жалоба отклонена')),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ошибка: $e'), backgroundColor: AppTheme.errorColor));
    }
  }

  String _typeLabel(ReportTargetType t) {
    switch (t) {
      case ReportTargetType.song:
        return 'Трек';
      case ReportTargetType.playlist:
        return 'Плейлист';
      case ReportTargetType.profile:
        return 'Профиль';
      case ReportTargetType.comment:
        return 'Комментарий';
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<ReportItem>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('Ошибка: ${snap.error}'))]);
          }
          final reports = snap.data ?? const [];
          if (reports.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 80),
              Center(child: Text('Нет открытых жалоб')),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final r = reports[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_typeLabel(r.targetType)}: ${r.targetId}',
                          style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('Причина: ${r.reason}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (r.details?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text('Подробности: ${r.details}'),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () =>
                                _setStatus(r, ReportStatus.dismissed),
                            child: const Text('Отклонить'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () =>
                                _setStatus(r, ReportStatus.resolved),
                            child: const Text('Разобрано'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Shared note prompt
// ----------------------------------------------------------------------------
Future<String?> _askNote(BuildContext context, String label,
    {bool required = false}) {
  return showDialog<String?>(
    context: context,
    builder: (ctx) => _NoteDialog(label: label, required: required),
  );
}

class _NoteDialog extends StatefulWidget {
  final String label;
  final bool required;
  const _NoteDialog({required this.label, required this.required});

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.label),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (widget.required && text.isEmpty) return;
            Navigator.pop(context, text);
          },
          child: const Text('Готово'),
        ),
      ],
    );
  }
}
