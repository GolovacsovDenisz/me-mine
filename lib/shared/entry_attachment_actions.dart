import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../features/journal/domain/utils/music_attachment_utils.dart';

enum EntryPhotoSource { gallery, camera }

Future<List<String>> pickEntryPhotoPaths(BuildContext context) async {
  final source = await showModalBottomSheet<EntryPhotoSource>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(EntryPhotoSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop(EntryPhotoSource.camera),
            ),
          ],
        ),
      );
    },
  );
  if (source == null) return const [];

  final picker = ImagePicker();
  switch (source) {
    case EntryPhotoSource.gallery:
      final images = await picker.pickMultiImage();
      return images
          .map((i) => i.path)
          .where((p) => p.isNotEmpty)
          .take(12)
          .toList(growable: false);
    case EntryPhotoSource.camera:
      final image = await picker.pickImage(source: ImageSource.camera);
      final path = image?.path;
      return path == null || path.isEmpty ? const [] : [path];
  }
}

Future<String?> promptForYoutubeMusic(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (context) => const _AddMusicDialog(),
  );
}

class _AddMusicDialog extends StatefulWidget {
  const _AddMusicDialog();

  @override
  State<_AddMusicDialog> createState() => _AddMusicDialogState();
}

class _AddMusicDialogState extends State<_AddMusicDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final trimmed = _controller.text.trim();
    if (extractYoutubeVideoId(trimmed) == null) {
      setState(() {
        _errorText = 'Paste a valid YouTube or YouTube Music link.';
      });
      return;
    }
    Navigator.of(context).pop(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add music'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'YouTube or YouTube Music link',
          hintText: 'https://music.youtube.com/watch?v=...',
          errorText: _errorText,
        ),
        keyboardType: TextInputType.url,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
