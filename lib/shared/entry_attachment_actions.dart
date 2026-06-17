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

Future<String?> promptForYoutubeMusic(BuildContext context) async {
  final controller = TextEditingController();
  try {
    return showDialog<String>(
      context: context,
      builder: (context) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add music'),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'YouTube or YouTube Music link',
                  hintText: 'https://music.youtube.com/watch?v=...',
                  errorText: errorText,
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submitMusicDialog(
                  context,
                  controller.text,
                  setDialogState,
                  (value) => errorText = value,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => _submitMusicDialog(
                    context,
                    controller.text,
                    setDialogState,
                    (value) => errorText = value,
                  ),
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    controller.dispose();
  }
}

void _submitMusicDialog(
  BuildContext context,
  String input,
  StateSetter setDialogState,
  ValueChanged<String?> setError,
) {
  final trimmed = input.trim();
  if (extractYoutubeVideoId(trimmed) == null) {
    setDialogState(() {
      setError('Paste a valid YouTube or YouTube Music link.');
    });
    return;
  }
  Navigator.of(context).pop(trimmed);
}
