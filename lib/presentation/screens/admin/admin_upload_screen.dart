import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../data/services/admin/admin_storage_service.dart';

class AdminUploadScreen extends StatefulWidget {
  const AdminUploadScreen({super.key});

  @override
  State<AdminUploadScreen> createState() => _AdminUploadScreenState();
}

class _AdminUploadScreenState extends State<AdminUploadScreen> {
  final _artistController = TextEditingController();
  final _titleController = TextEditingController();
  String _bucket = 'songs';
  PlatformFile? _audioFile;
  PlatformFile? _coverFile;
  bool _uploading = false;

  @override
  void dispose() {
    _artistController.dispose();
    _titleController.dispose();
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

    if (_artistController.text.isEmpty && _titleController.text.isEmpty) {
      final name = _audioFile!.name.replaceAll(RegExp(r'\.[^.]+$'), '');
      if (name.contains(' - ')) {
        final parts = name.split(' - ');
        _artistController.text = parts.first.trim();
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

    final audioExtension = _audioFile!.extension ?? 'mp3';
    final success = await AdminStorageService.uploadSong(
      bucket: _bucket,
      artist: artist,
      title: title,
      fileBytes: _audioFile!.bytes!,
      fileExtension: audioExtension,
    );

    if (success && _coverFile != null && _coverFile!.bytes != null) {
      final coverExtension = _coverFile!.extension ?? 'jpg';
      await AdminStorageService.uploadCover(
        songFileName: '$artist - $title.$audioExtension',
        bytes: _coverFile!.bytes!,
        extension: coverExtension,
      );
    }

    if (!mounted) return;
    setState(() => _uploading = false);

    if (!success) {
      _showError('Ошибка загрузки. Проверьте права.');
      return;
    }

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
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Новая песня',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _artistController,
          decoration: const InputDecoration(
            labelText: 'Исполнитель',
            prefixIcon: Icon(Icons.person),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Название',
            prefixIcon: Icon(Icons.music_note),
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
          icon: Icons.image,
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
          label: Text(_uploading ? 'Загрузка...' : 'Загрузить'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
      ],
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
