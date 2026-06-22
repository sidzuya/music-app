import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/report_model.dart';
import '../../data/services/reports_service.dart';

/// Shows a dialog letting the user submit a report against any target.
/// Returns true if a report was successfully submitted.
Future<bool> showReportDialog(
  BuildContext context, {
  required ReportTargetType targetType,
  required String targetId,
  String? targetTitle,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => _ReportDialog(
      targetType: targetType,
      targetId: targetId,
      targetTitle: targetTitle,
    ),
  );
  return result ?? false;
}

class _ReportDialog extends StatefulWidget {
  final ReportTargetType targetType;
  final String targetId;
  final String? targetTitle;
  const _ReportDialog({
    required this.targetType,
    required this.targetId,
    this.targetTitle,
  });

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  static const List<String> _reasons = [
    'Нарушение авторских прав',
    'Запрещённый контент',
    'Спам / накрутка',
    'Оскорбительное содержание',
    'Другое',
  ];

  String _reason = _reasons.first;
  final _detailsController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _submitting = true);
    try {
      await ReportsService.submit(
        targetType: widget.targetType,
        targetId: widget.targetId,
        reason: _reason,
        details: _detailsController.text.isEmpty
            ? null
            : _detailsController.text,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Жалоба отправлена')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось отправить: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.targetTitle != null
          ? 'Пожаловаться: ${widget.targetTitle}'
          : 'Пожаловаться'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Причина:'),
            ..._reasons.map(
              (r) => RadioListTile<String>(
                title: Text(r),
                value: r,
                groupValue: _reason,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => _reason = v ?? _reasons.first),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _detailsController,
              decoration: const InputDecoration(
                labelText: 'Подробности (необязательно)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _send,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Отправить'),
        ),
      ],
    );
  }
}
