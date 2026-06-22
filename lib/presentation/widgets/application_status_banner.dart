import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/artist_application_model.dart';
import '../../data/services/artist_application_service.dart';
import '../screens/artist/artist_application_screen.dart';

/// Once-per-decision in-app banner shown on top of any screen that mounts
/// it. Pulls the current user's latest application; if it has been reviewed
/// (approved/rejected) and the user hasn't acknowledged it yet, displays a
/// dismissible MaterialBanner.
class ApplicationStatusBanner extends StatefulWidget {
  const ApplicationStatusBanner({super.key});

  @override
  State<ApplicationStatusBanner> createState() =>
      _ApplicationStatusBannerState();
}

class _ApplicationStatusBannerState extends State<ApplicationStatusBanner> {
  static const _prefsKey = 'last_seen_application_reviewed_at';

  ArtistApplication? _app;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final app = await ArtistApplicationService.myLatest();
      if (app == null ||
          app.status == ArtistApplicationStatus.pending ||
          app.reviewedAt == null) {
        if (mounted) setState(() => _checked = true);
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final lastSeen = prefs.getString(_prefsKey);
      final reviewedAt = app.reviewedAt!.toIso8601String();
      if (lastSeen == reviewedAt) {
        if (mounted) setState(() => _checked = true);
        return;
      }
      if (mounted) {
        setState(() {
          _app = app;
          _checked = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _checked = true);
    }
  }

  Future<void> _dismiss() async {
    final reviewedAt = _app?.reviewedAt?.toIso8601String();
    if (reviewedAt != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, reviewedAt);
    }
    if (mounted) setState(() => _app = null);
  }

  void _open() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ArtistApplicationScreen()),
    ).then((_) => _dismiss());
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked || _app == null) return const SizedBox.shrink();
    final approved = _app!.status == ArtistApplicationStatus.approved;
    final color = approved ? Colors.green : AppTheme.errorColor;
    final icon = approved ? Icons.verified : Icons.cancel;
    final text = approved
        ? 'Ваша заявка одобрена! Теперь вы исполнитель.'
        : 'Заявка отклонена${_app!.reviewerNote?.isNotEmpty == true ? ': ${_app!.reviewerNote}' : '.'}';

    return Material(
      color: color.withOpacity(0.12),
      child: InkWell(
        onTap: _open,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(child: Text(text)),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: _dismiss,
                tooltip: 'Закрыть',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
