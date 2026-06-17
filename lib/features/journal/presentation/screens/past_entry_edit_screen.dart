import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/formatting/journal_date_format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/app_dialogs.dart';
import '../../../../shared/entry_attachment_actions.dart';
import '../../../../shared/entry_attachments_ui.dart';
import '../../../../shared/ui_feedback.dart';
import '../../domain/entities/entry.dart';
import '../../domain/utils/journal_date_utils.dart';
import '../providers/entries_providers.dart';

enum _ExitChoice { save, discard, cancel }

class PastEntryEditScreen extends ConsumerStatefulWidget {
  const PastEntryEditScreen({super.key, required this.dateId});

  final String dateId;

  @override
  ConsumerState<PastEntryEditScreen> createState() =>
      _PastEntryEditScreenState();
}

class _PastEntryEditScreenState extends ConsumerState<PastEntryEditScreen> {
  final _textController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  int _rating = 0;
  bool _saving = false;
  int _uploadTasks = 0;
  bool _draftDirty = false;
  bool _allowPop = false;
  String _savedText = '';
  int _savedRating = 0;

  bool get _uploading => _uploadTasks > 0;
  bool get _hasUnsavedTextChanges =>
      _textController.text.trim() != _savedText.trim() ||
      _rating != _savedRating;

  DateTime get _day {
    final d = JournalDateUtils.tryParseDateId(widget.dateId);
    if (d == null) {
      throw StateError('Invalid dateId: ${widget.dateId}');
    }
    return d;
  }

  bool get _isToday =>
      widget.dateId == JournalDateUtils.dateId(DateTime.now());

  void _applyRemote(Entry? e) {
    if (!mounted || e == null || _draftDirty) return;
    _savedText = e.text;
    _savedRating = e.rating;
    if (_textController.text == e.text && _rating == e.rating) return;
    setState(() {
      _textController.text = e.text;
      _rating = e.rating;
    });
  }

  void _markDraftDirty() {
    if (_draftDirty) return;
    setState(() => _draftDirty = true);
  }

  Future<bool> _onSave({bool showSuccess = true}) async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return false;
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating (1–5).')),
      );
      return false;
    }

    try {
      setState(() => _saving = true);
      final text = _textController.text.trim();
      await ref
          .read(entriesRepositoryProvider)
          .upsertEntryForDateId(
            dateId: widget.dateId,
            text: text,
            rating: _rating,
          );
      if (!mounted) return false;
      setState(() {
        _draftDirty = false;
        _savedText = text;
        _savedRating = _rating;
      });
      if (showSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry saved successfully')),
        );
      }
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingErrorMessage(e))));
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _onDelete() async {
    final ok = await showAppConfirmDialog(
      context: context,
      icon: Icon(
        Icons.delete_forever,
        color: Theme.of(context).colorScheme.error,
      ),
      title: 'Delete this day?',
      contentText:
          'Remove the entry for ${formatJournalDateId(widget.dateId)}? '
          'Uploaded files in Storage may remain until cleaned up separately.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (ok != true || !mounted) return;

    try {
      setState(() => _saving = true);
      await ref
          .read(entriesRepositoryProvider)
          .deleteEntryForDateId(widget.dateId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Entry deleted')));
      _allowPop = true;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmExitIfEdited() async {
    if (!_hasUnsavedTextChanges || _allowPop) return true;

    final choice = await showDialog<_ExitChoice>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('This entry has been edited. Save changes?'),
        content: const Text('Save your changes before leaving this entry?'),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(_ExitChoice.save),
                child: const Text('Save'),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(_ExitChoice.discard),
                child: const Text('Discard'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(_ExitChoice.cancel),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );

    if (!mounted) return false;
    switch (choice) {
      case _ExitChoice.save:
        return _onSave(showSuccess: false);
      case _ExitChoice.discard:
        return true;
      case _ExitChoice.cancel:
      case null:
        return false;
    }
  }

  Future<void> _handleBlockedPop() async {
    final shouldPop = await _confirmExitIfEdited();
    if (!mounted || !shouldPop) return;
    _allowPop = true;
    Navigator.of(context).pop();
  }

  Future<void> _confirmAndRemoveAttachment({
    required String title,
    required String contentText,
    required Future<void> Function() remove,
  }) async {
    if (_uploading) return;
    final confirm = await showAppConfirmDialog(
      context: context,
      title: title,
      contentText: contentText,
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (!mounted || confirm != true) return;

    setState(() => _uploadTasks++);
    try {
      await remove();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingErrorMessage(e))));
    } finally {
      if (mounted) {
        setState(() => _uploadTasks = (_uploadTasks - 1).clamp(0, 99));
      }
    }
  }

  Future<void> _addPhoto() async {
    try {
      final paths = await pickEntryPhotoPaths(context);
      if (paths.isEmpty) return;

      setState(() => _uploadTasks++);
      await ref
          .read(entriesRepositoryProvider)
          .addImagesForDate(date: _day, filePaths: paths);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingErrorMessage(e))));
    } finally {
      if (mounted) {
        setState(() => _uploadTasks = (_uploadTasks - 1).clamp(0, 99));
      }
    }
  }

  Future<void> _addMusic() async {
    try {
      final input = await promptForYoutubeMusic(context);
      if (input == null || input.trim().isEmpty) return;

      setState(() => _uploadTasks++);
      await ref
          .read(entriesRepositoryProvider)
          .addMusicForDate(date: _day, input: input);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingErrorMessage(e))));
    } finally {
      if (mounted) {
        setState(() => _uploadTasks = (_uploadTasks - 1).clamp(0, 99));
      }
    }
  }

  Future<void> _addLocation() async {
    try {
      setState(() => _uploadTasks++);
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied.')),
        );
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      await ref
          .read(entriesRepositoryProvider)
          .addLocationForDate(
            date: _day,
            lat: pos.latitude,
            lng: pos.longitude,
            accuracyMeters: pos.accuracy,
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingErrorMessage(e))));
    } finally {
      if (mounted) {
        setState(() => _uploadTasks = (_uploadTasks - 1).clamp(0, 99));
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entryAsync = ref.watch(entryByDateIdProvider(widget.dateId));

    ref.listen(entryByDateIdProvider(widget.dateId), (prev, next) {
      next.whenData(_applyRemote);
    });

    return PopScope<void>(
      canPop: !_hasUnsavedTextChanges || _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBlockedPop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(formatJournalDateId(widget.dateId)),
          actions: [
            TextButton(
              onPressed: _saving ? null : _onDelete,
              child: Text(
                'Delete',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: entryAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AppErrorState(
              error: e,
              title: 'Couldn’t load entry',
              onRetry: () =>
                  ref.invalidate(entryByDateIdProvider(widget.dateId)),
            ),
            data: (remoteEntry) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _applyRemote(remoteEntry);
              });
              final entry =
                  remoteEntry ??
                  Entry(
                    id: widget.dateId,
                    dateId: widget.dateId,
                    text: '',
                    rating: 0,
                    imageUrls: const [],
                    localImagePaths: const [],
                    files: const [],
                    location: null,
                    music: null,
                    createdAt: null,
                    updatedAt: null,
                  );
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!_isToday)
                          Card.filled(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Editing a past calendar day. '
                                      'Use Home for today’s new entry.',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (!_isToday) const SizedBox(height: 12),
                        Form(
                          key: _formKey,
                          child: TextFormField(
                            controller: _textController,
                            minLines: 8,
                            maxLines: 14,
                            decoration: const InputDecoration(
                              labelText: 'How was your day?',
                            ),
                            keyboardType: TextInputType.multiline,
                            onChanged: (_) => _markDraftDirty(),
                            validator: (v) => (v?.trim().isEmpty ?? true)
                                ? 'Please enter your entry'
                                : null,
                          ),
                        ),
                        if (entry.imageSources.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          EntryPhotoCarousel(
                            imageUrls: entry.imageSources,
                            onPhotoLongPress: _uploading
                                ? null
                                : (index) {
                                    final url = entry.imageSources[index];
                                    _confirmAndRemoveAttachment(
                                      title: 'Remove photo?',
                                      contentText:
                                          'This photo will be removed from this day.',
                                      remove: () => ref
                                          .read(entriesRepositoryProvider)
                                          .removeImageForDateId(
                                            dateId: widget.dateId,
                                            imageUrl: url,
                                          ),
                                    );
                                  },
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (entry.imageSources.isNotEmpty)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AttachmentToolbarIcon(
                                icon: Icons.music_note_outlined,
                                tooltip: 'Add music',
                                onPressed: _addMusic,
                              ),
                              const SizedBox(width: 10),
                              AttachmentToolbarIcon(
                                icon: Icons.add_photo_alternate_outlined,
                                tooltip: 'Add photos',
                                onPressed: _addPhoto,
                              ),
                              const SizedBox(width: 10),
                              AttachmentToolbarIcon(
                                icon: Icons.location_on_outlined,
                                tooltip: 'Add location',
                                onPressed: _addLocation,
                              ),
                            ],
                          )
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AttachmentIconTile(
                                icon: Icons.music_note_outlined,
                                onPressed: _addMusic,
                              ),
                              const SizedBox(width: 12),
                              AttachmentIconTile(
                                icon: Icons.location_on_outlined,
                                onPressed: _addLocation,
                              ),
                              const SizedBox(width: 12),
                              AttachmentIconTile(
                                icon: Icons.add_photo_alternate_outlined,
                                onPressed: _addPhoto,
                              ),
                            ],
                          ),
                        if (entry.files.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          for (final f in entry.files)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: EntryFileRow(
                                name: f.name,
                                onLongPress: _uploading
                                    ? null
                                    : () => _confirmAndRemoveAttachment(
                                        title: 'Remove file?',
                                        contentText:
                                            '“${f.name}” will be removed from this day.',
                                        remove: () => ref
                                            .read(entriesRepositoryProvider)
                                            .removeFileForDateId(
                                              dateId: widget.dateId,
                                              file: f,
                                            ),
                                      ),
                              ),
                            ),
                        ],
                        if (entry.music != null) ...[
                          const SizedBox(height: 12),
                          EntryMusicCard(
                            music: entry.music!,
                            onLongPress: _uploading
                                ? null
                                : () => _confirmAndRemoveAttachment(
                                    title: 'Remove music?',
                                    contentText:
                                        'Music will be removed from this day.',
                                    remove: () => ref
                                        .read(entriesRepositoryProvider)
                                        .removeMusicForDateId(widget.dateId),
                                  ),
                          ),
                        ],
                        if (entry.location != null) ...[
                          const SizedBox(height: 12),
                          EntryLocationChip(
                            location: entry.location!,
                            onLongPress: _uploading
                                ? null
                                : () => _confirmAndRemoveAttachment(
                                    title: 'Remove location?',
                                    contentText:
                                        'Location will be removed from this day.',
                                    remove: () => ref
                                        .read(entriesRepositoryProvider)
                                        .removeLocationForDateId(widget.dateId),
                                  ),
                          ),
                        ],
                        if (entry.imageSources.isNotEmpty ||
                            entry.files.isNotEmpty ||
                            entry.music != null ||
                            entry.location != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Long-press a photo, music, file, or location to remove',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                        if (_uploading) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Uploading attachment…',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        VolumetricStarRating(
                          rating: _rating,
                          enabled: !_saving,
                          onRatingChanged: (v) => setState(() {
                            _draftDirty = true;
                            _rating = v;
                          }),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: AppColors.white,
                          ),
                          onPressed: _saving ? null : () => _onSave(),
                          child: Text(_saving ? 'Saving...' : 'Save changes'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
