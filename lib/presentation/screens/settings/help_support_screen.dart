import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/report_model.dart';
import '../../../data/services/reports_service.dart';

/// In-app help center: FAQ, ability to file a report against any content
/// (track / playlist / profile / comment), contact info and app version.
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const _supportEmail = 'support@musicapp.local';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Помощь и поддержка')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          _section('Часто задаваемые вопросы'),
          ..._faq.map((qa) => _FaqTile(question: qa.q, answer: qa.a)),
          const SizedBox(height: 16),

          _section('Сообщить о проблеме'),
          _ActionTile(
            icon: Icons.flag_outlined,
            color: AppTheme.errorColor,
            title: 'Пожаловаться на контент',
            subtitle: 'Трек, плейлист, профиль или комментарий',
            onTap: () => _openReportSheet(context),
          ),
          const SizedBox(height: 16),

          _section('Связаться с нами'),
          _ActionTile(
            icon: Icons.email_outlined,
            color: Colors.blueAccent,
            title: _supportEmail,
            subtitle: 'Нажмите, чтобы скопировать',
            onTap: () async {
              await Clipboard.setData(
                  const ClipboardData(text: _supportEmail));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Email скопирован')),
              );
            },
          ),
          const SizedBox(height: 24),

          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Music App · v1.0.0',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 0.6,
              color: AppTheme.textSecondary),
        ),
      );

  Future<void> _openReportSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _SupportReportSheet(),
    );
  }

  static const List<_Faq> _faq = [
    _Faq(
      'Как стать исполнителем?',
      'Перейдите в Профиль → «Стать исполнителем» и заполните заявку. '
          'Модератор рассмотрит её и при одобрении вам будет выдана роль '
          'исполнителя — после этого появится раздел «Студия исполнителя» '
          'для загрузки треков.',
    ),
    _Faq(
      'Почему мой загруженный трек не виден другим?',
      'Каждый трек проходит премодерацию. После загрузки он имеет статус '
          '«На модерации». Когда модератор одобрит трек, он появится в поиске '
          'и на главной у всех пользователей.',
    ),
    _Faq(
      'Как пожаловаться на конкретный трек?',
      'Откройте плеер и нажмите на меню (три точки) → «Пожаловаться». '
          'Также можно отправить жалобу из раздела «Помощь и поддержка», '
          'выбрав тип контента.',
    ),
    _Faq(
      'Что делать, если заявку отклонили?',
      'В разделе «Стать исполнителем» вы увидите статус и причину отказа. '
          'Учтите замечания и подайте заявку снова.',
    ),
    _Faq(
      'Как работают AI-плейлисты?',
      'AI анализирует ваши прослушивания и предлагает подборки. '
          'Чем активнее вы слушаете, тем точнее становятся рекомендации.',
    ),
  ];
}

class _Faq {
  final String q;
  final String a;
  const _Faq(this.q, this.a);
}

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;
  const _FaqTile({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Card(
        margin: EdgeInsets.zero,
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding:
              const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(question,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(answer),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, color: color),
          ),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}

// ============================================================================
// Bottom sheet form for filing a report from the support screen.
// ============================================================================
class _SupportReportSheet extends StatefulWidget {
  const _SupportReportSheet();

  @override
  State<_SupportReportSheet> createState() => _SupportReportSheetState();
}

class _SupportReportSheetState extends State<_SupportReportSheet> {
  static const _reasons = [
    'Нарушение авторских прав',
    'Запрещённый контент',
    'Спам / накрутка',
    'Оскорбительное содержание',
    'Бот / накрутка прослушиваний',
    'Другое',
  ];

  ReportTargetType _type = ReportTargetType.song;
  String _reason = _reasons.first;
  final _targetController = TextEditingController();
  final _detailsController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _targetController.dispose();
    _detailsController.dispose();
    super.dispose();
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

  String _targetHint() {
    switch (_type) {
      case ReportTargetType.song:
        return 'Название трека, исполнитель или ссылка';
      case ReportTargetType.playlist:
        return 'Название или ссылка на плейлист';
      case ReportTargetType.profile:
        return 'Username или email пользователя';
      case ReportTargetType.comment:
        return 'Текст или ID комментария';
    }
  }

  Future<void> _send() async {
    final target = _targetController.text.trim();
    if (target.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите цель жалобы')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ReportsService.submit(
        targetType: _type,
        targetId: target,
        reason: _reason,
        details: _detailsController.text.trim().isEmpty
            ? null
            : _detailsController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Жалоба отправлена модераторам')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Не удалось отправить: $e'),
            backgroundColor: AppTheme.errorColor),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Пожаловаться',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Тип контента',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ReportTargetType.values
                  .map((t) => ChoiceChip(
                        label: Text(_typeLabel(t)),
                        selected: _type == t,
                        onSelected: (_) => setState(() => _type = t),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _targetController,
              decoration: InputDecoration(
                labelText: _targetHint(),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Причина',
                style: TextStyle(fontWeight: FontWeight.w600)),
            ..._reasons.map(
              (r) => RadioListTile<String>(
                value: r,
                groupValue: _reason,
                title: Text(r),
                contentPadding: EdgeInsets.zero,
                onChanged: (v) =>
                    setState(() => _reason = v ?? _reasons.first),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _detailsController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Подробности (необязательно)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _send,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: const Text('Отправить'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
