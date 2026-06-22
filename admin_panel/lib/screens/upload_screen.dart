import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../services/storage_service.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _artistController = TextEditingController();
  final _titleController = TextEditingController();
  String _bucket = 'songs';
  PlatformFile? _audioFile;
  PlatformFile? _coverFile;
  bool _uploading = false;

  Future<void> _pickAudio() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'wav', 'flac', 'aac'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _audioFile = result.files.first);
      // Auto-fill artist/title from filename
      if (_artistController.text.isEmpty && _titleController.text.isEmpty) {
        final name = _audioFile!.name.replaceAll(RegExp(r'\.[^.]+$'), '');
        if (name.contains(' - ')) {
          final parts = name.split(' - ');
          _artistController.text = parts[0].trim();
          _titleController.text = parts.sublist(1).join(' - ').trim();
        } else {
          _titleController.text = name;
        }
      }
    }
  }

  Future<void> _pickCover() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _coverFile = result.files.first);
    }
  }

  Future<void> _upload() async {
    final artist = _artistController.text.trim();
    final title = _titleController.text.trim();

    if (artist.isEmpty || title.isEmpty) {
      _showError('Заполните исполнителя и название');
      return;
    }
    if (_audioFile == null || _audioFile!.bytes == null) {
      _showError('Выберите аудиофайл');
      return;
    }

    setState(() => _uploading = true);

    final ext = _audioFile!.extension ?? 'mp3';
    final success = await StorageService.uploadSong(
      bucket: _bucket,
      artist: artist,
      title: title,
      fileBytes: _audioFile!.bytes!,
      fileExtension: ext,
    );

    if (success && _coverFile != null && _coverFile!.bytes != null) {
      final coverExt = _coverFile!.extension ?? 'jpg';
      await StorageService.uploadCover(
        songFileName: '$artist - $title.$ext',
        bytes: _coverFile!.bytes!,
        extension: coverExt,
      );
    }

    if (!mounted) return;
    setState(() => _uploading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$artist - $title загружен в $_bucket'),
          backgroundColor: Colors.green,
        ),
      );
      _artistController.clear();
      _titleController.clear();
      setState(() {
        _audioFile = null;
        _coverFile = null;
      });
    } else {
      _showError('Ошибка загрузки. Проверьте права.');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Загрузка песни')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Новая песня',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _artistController,
                      decoration: const InputDecoration(
                        labelText: 'Исполнитель',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Название',
                        prefixIcon: Icon(Icons.music_note),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'songs', label: Text('Songs')),
                        ButtonSegment(value: 'featured', label: Text('Featured')),
                      ],
                      selected: {_bucket},
                      onSelectionChanged: (v) {
                        setState(() => _bucket = v.first);
                      },
                    ),
                    const SizedBox(height: 24),
                    _FilePickerTile(
                      label: 'Аудиофайл',
                      fileName: _audioFile?.name,
                      icon: Icons.audiotrack,
                      onPick: _pickAudio,
                    ),
                    const SizedBox(height: 12),
                    _FilePickerTile(
                      label: 'Обложка (необязательно)',
                      fileName: _coverFile?.name,
                      icon: Icons.image,
                      onPick: _pickCover,
                    ),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: _uploading ? null : _upload,
                      icon: _uploading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_upload),
                      label: Text(_uploading ? 'Загрузка...' : 'Загрузить'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilePickerTile extends StatelessWidget {
  final String label;
  final String? fileName;
  final IconData icon;
  final VoidCallback onPick;

  const _FilePickerTile({
    required this.label,
    required this.fileName,
    required this.icon,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPick,
      icon: Icon(icon),
      label: Text(
        fileName ?? label,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        alignment: Alignment.centerLeft,
      ),
    );
  }
}
