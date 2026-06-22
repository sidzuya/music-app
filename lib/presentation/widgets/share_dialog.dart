import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/song_model.dart';

void showShareDialog(BuildContext context, SongModel song, String shareUrl) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      final message = 'Послушай трек "${song.title}" исполнителя "${song.artist}" на MusicApp:';
      final fullShareText = '$message $shareUrl';

      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E), // sleek dark card
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 15,
                spreadRadius: 2,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Поделиться',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${song.title} — ${song.artist}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ShareOption(
                    color: const Color(0xFF29A9EA), // Telegram blue
                    icon: Icons.send_rounded,
                    label: 'Telegram',
                    onTap: () async {
                      final url = 'https://t.me/share/url?url=${Uri.encodeComponent(shareUrl)}&text=${Uri.encodeComponent(message)}';
                      await _launch(url);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                  _ShareOption(
                    color: const Color(0xFF25D366), // WhatsApp green
                    icon: Icons.chat_bubble_rounded,
                    label: 'WhatsApp',
                    onTap: () async {
                      final url = 'https://api.whatsapp.com/send?text=${Uri.encodeComponent(fullShareText)}';
                      await _launch(url);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                  _ShareOption(
                    color: const Color(0xFF4C75A3), // VK blue
                    icon: Icons.link_rounded,
                    label: 'ВКонтакте',
                    onTap: () async {
                      final url = 'https://vk.com/share.php?url=${Uri.encodeComponent(shareUrl)}&title=${Uri.encodeComponent(fullShareText)}';
                      await _launch(url);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                  _ShareOption(
                    color: Colors.white24, // Copy Link grey
                    icon: Icons.copy_rounded,
                    label: 'Ссылка',
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: shareUrl));
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Ссылка на трек скопирована в буфер обмена'),
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _launch(String url) async {
  final uri = Uri.parse(url);
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('Could not launch URL: $e');
  }
}

class _ShareOption extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ShareOption({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
