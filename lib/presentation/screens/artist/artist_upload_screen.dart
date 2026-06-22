import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/services/songs_catalog_service.dart';

/// Lets an artist upload a new song. The DB row is created with
/// status='pending' and the moderator must approve before it goes public.
class ArtistUploadScreen extends StatefulWidget {
  const ArtistUploadScreen({super.key});

  @override
  State<ArtistUploadScreen> createState() => _ArtistUploadScreenState();
}

class _ArtistUploadScreenState extends State<ArtistUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _artistController = TextEditingController();
  final _titleController = TextEditingController();
  final _albumController = TextEditingController();
  final _genreController = TextEditingController();

  PlatformFile? _audioFile;
  PlatformFile? _coverFile;
  bool _uploading = false;

  @override
  void dispose() {
    _artistController.dispose();
    _titleController.dispose();
    _albumController.dispose();
    _genreController.dispose();
    super.dispose();
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'wav', 'flac', 'aac'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _audioFile = result.files.first);

    if (_titleController.text.isEmpty) {
      final name = _audioFile!.name.replaceAll(RegExp(r'\.[^.]+$'), '');
      if (name.contains(' - ')) {
        final parts = name.split(' - ');
        if (_artistController.text.isEmpty) {
          _artistController.text = parts.first.trim();
        }
        _titleController.text = parts.skip(1).join(' - ').trim();
      } else {
        _titleController.text = name;
      }
    }
  }

  Future<void> _pickCover() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _coverFile = result.files.first);
  }

  Future<void> _upload() async {
    if (!_formKey.currentState!.validate()) return;
    if (_audioFile == null || _audioFile!.bytes == null) {
      _toast('Выберите аудиофайл', error: true);
      return;
    }

    setState(() => _uploading = true);
    try {
      await SongsCatalogService.uploadAsArtist(
        title: _titleController.text,
        artist: _artistController.text,
        audioBytes: _audioFile!.bytes!,
        audioExtension: _audioFile!.extension ?? 'mp3',
        album: _albumController.text.isEmpty ? null : _albumController.text,
        genre: _genreController.text.isEmpty ? null : _genreController.text,
        coverBytes: _coverFile?.bytes,
        coverExtension:
            _coverFile != null ? (_coverFile!.extension ?? 'jpg') : null,
      );
      if (!mounted) return;
      _toast('Трек отправлен на модерацию');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _toast('Ошибка загрузки: $e', error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
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
      appBar: AppBar(title: const Text('Загрузить трек')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _InfoBanner(
                text:
                    'Трек проходит проверку модератором. После одобрения он станет '
                    'виден всем пользователям.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _artistController,
                decoration: const InputDecoration(
                  labelText: 'Исполнитель',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Обязательно' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Название',
                  prefixIcon: Icon(Icons.music_note_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Обязательно' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _albumController,
                decoration: const InputDecoration(
                  labelText: 'Альбом (необязательно)',
                  prefixIcon: Icon(Icons.album_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _genreController,
                decoration: const InputDecoration(
                  labelText: 'Жанр (необязательно)',
                  prefixIcon: Icon(Icons.category_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              _FilePickerButton(
                label: 'Аудиофайл',
                fileName: _audioFile?.name,
                icon: Icons.audiotrack,
                onPressed: _pickAudio,
              ),
              const SizedBox(height: 10),
              _FilePickerButton(
                label: 'Обложка (необязательно)',
                fileName: _coverFile?.name,
                icon: Icons.image_outlined,
                onPressed: _pickCover,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _uploading ? null : _upload,
                icon: _uploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(_uploading ? 'Загрузка...' : 'Отправить на модерацию'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilePickerButton extends StatelessWidget {
  final String label;
  final String? fileName;
  final IconData icon;
  final VoidCallback onPressed;
  const _FilePickerButton({
    required this.label,
    required this.fileName,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(fileName ?? label, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        alignment: Alignment.centerLeft,
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String text;
  const _InfoBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
