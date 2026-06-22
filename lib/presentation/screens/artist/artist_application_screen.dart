import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/artist_application_model.dart';
import '../../../data/services/artist_application_service.dart';
import '../../../data/services/role_service.dart';

/// Lets a regular user submit an application to become an artist
/// and view the status of their latest application.
class ArtistApplicationScreen extends StatefulWidget {
  const ArtistApplicationScreen({super.key});

  @override
  State<ArtistApplicationScreen> createState() =>
      _ArtistApplicationScreenState();
}

class _ArtistApplicationScreenState extends State<ArtistApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _linksController = TextEditingController();
  final _reasonController = TextEditingController();

  bool _loading = true;
  bool _submitting = false;
  ArtistApplication? _latest;
  bool _isArtist = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _linksController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final latest = await ArtistApplicationService.myLatest();
      final isArtist = await RoleService.isArtist();
      if (!mounted) return;
      setState(() {
        _latest = latest;
        _isArtist = isArtist;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('Не удалось загрузить заявку: $e', error: true);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await ArtistApplicationService.submit(
        artistName: _nameController.text,
        reason: _reasonController.text,
        bio: _bioController.text.isEmpty ? null : _bioController.text,
        links: _linksController.text.isEmpty ? null : _linksController.text,
      );
      if (!mounted) return;
      _toast('Заявка отправлена. Ожидайте рассмотрения модератором.');
      await _load();
    } catch (e) {
      if (!mounted) return;
      _toast('Ошибка отправки: $e', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _withdraw() async {
    final app = _latest;
    if (app == null || app.status != ArtistApplicationStatus.pending) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отозвать заявку?'),
        content: const Text(
          'Вы сможете подать новую заявку в любой момент.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Отозвать'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ArtistApplicationService.withdraw(app.id);
      if (!mounted) return;
      _toast('Заявка отозвана');
      await _load();
    } catch (e) {
      if (!mounted) return;
      _toast('Не удалось отозвать: $e', error: true);
    }
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppTheme.errorColor : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Стать исполнителем')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildBody(context),
              ),
            ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final latest = _latest;
    if (_isArtist) {
      return _StatusCard(
        icon: Icons.verified,
        color: Colors.green,
        title: 'Вы исполнитель',
        message:
            'Заявка одобрена. Перезайдите в приложение, если разделы исполнителя ещё не появились.',
      );
    }
    if (latest != null && latest.status == ArtistApplicationStatus.pending) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusCard(
            icon: Icons.hourglass_top,
            color: Colors.orange,
            title: 'Заявка на рассмотрении',
            message:
                'Модератор рассмотрит заявку в ближайшее время. Вы получите уведомление в приложении.',
          ),
          const SizedBox(height: 16),
          _ApplicationDetails(application: latest),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.delete_outline),
            label: const Text('Отозвать заявку'),
            onPressed: _withdraw,
          ),
        ],
      );
    }

    // No application yet, or last was rejected — allow new submission.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (latest != null &&
            latest.status == ArtistApplicationStatus.rejected) ...[
          _StatusCard(
            icon: Icons.cancel,
            color: AppTheme.errorColor,
            title: 'Прошлая заявка отклонена',
            message: latest.reviewerNote?.isNotEmpty == true
                ? 'Причина: ${latest.reviewerNote}'
                : 'Вы можете подать заявку повторно ниже.',
          ),
          const SizedBox(height: 16),
        ],
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Имя исполнителя',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Минимум 2 символа'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: 'О себе (необязательно)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _linksController,
                decoration: const InputDecoration(
                  labelText: 'Ссылки на ваши треки/соцсети (необязательно)',
                  hintText: 'Spotify, SoundCloud, Instagram и т.д.',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Почему вы хотите стать исполнителем',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                validator: (v) => (v == null || v.trim().length < 10)
                    ? 'Опишите причину подробнее (минимум 10 символов)'
                    : null,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: const Text('Отправить заявку'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // The role cache is invalidated when status changes externally;
  // ensure the consumer can re-check.
  @override
  void deactivate() {
    RoleService.invalidate();
    super.deactivate();
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  const _StatusCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplicationDetails extends StatelessWidget {
  final ArtistApplication application;
  const _ApplicationDetails({required this.application});

  @override
  Widget build(BuildContext context) {
    final created =
        '${application.createdAt.day.toString().padLeft(2, '0')}.${application.createdAt.month.toString().padLeft(2, '0')}.${application.createdAt.year}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Имя: ${application.artistName}',
                style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Text('Дата подачи: $created'),
            if (application.bio?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text('О себе: ${application.bio}'),
            ],
            if (application.links?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text('Ссылки: ${application.links}'),
            ],
            const SizedBox(height: 6),
            Text('Причина: ${application.reason}'),
          ],
        ),
      ),
    );
  }
}
