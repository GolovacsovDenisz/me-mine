import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/formatting/journal_date_format.dart';
import '../../core/navigation/app_page_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/app_dialogs.dart';
import '../../shared/entry_attachment_actions.dart';
import '../../models/entry.dart';
import '../../shared/app_motion_widgets.dart';
import '../../shared/entry_attachments_ui.dart';
import '../../shared/ui_feedback.dart';
import 'entries_repository.dart';
import 'past_entry_edit_screen.dart';

bool _entryHasListableContent(Entry e) {
  return e.text.trim().isNotEmpty ||
      e.rating > 0 ||
      e.imageSources.isNotEmpty ||
      e.files.isNotEmpty ||
      e.location != null ||
      e.music != null;
}

String _entryPreviewTitle(Entry e) {
  final t = e.text.trim();
  if (t.isEmpty) {
    if (e.imageSources.isNotEmpty) return 'Photo';
    if (e.music != null) return 'Music';
    if (e.files.isNotEmpty) return 'Attachment';
    if (e.location != null) return 'Location';
    if (e.rating > 0) return 'Rating only';
    return 'Empty entry';
  }
  final line = t.split(RegExp(r'\r?\n')).first.trim();
  if (line.length > 42) return '${line.substring(0, 42)}…';
  return line;
}

/// Recent calendar days before today (newest first) for the Home archive list.
final recentPastEntriesProvider = StreamProvider<List<Entry>>((ref) {
  final repo = ref.watch(entriesRepositoryProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final from = today.subtract(const Duration(days: 400));
  final to = today.subtract(const Duration(days: 1));
  return repo.watchEntriesForRange(from: from, to: to).map((list) {
    final filtered = list
        .where(_entryHasListableContent)
        .toList(growable: false);
    return filtered.reversed.toList(growable: false);
  });
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.onEntrySaved});

  /// Called after a successful save (e.g. switch to Calendar tab).
  final VoidCallback? onEntrySaved;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _rating = 0;
  final _textController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  int _uploadTasks = 0;

  bool get _uploading => _uploadTasks > 0;

  /// True after the user edits text or stars; blocks overwriting the form from Firestore
  /// when attachments or other fields update the same document.
  bool _draftDirty = false;
  late String _activeDateId = EntriesRepository.dateId(DateTime.now());

  void _markDraftDirty() {
    if (_draftDirty) return;
    setState(() => _draftDirty = true);
  }

  /// Pull text + rating from Firestore when the user is not mid-edit.
  void _applyRemoteEntry(Entry? entry) {
    if (!mounted || entry == null) return;
    if (_draftDirty) return;
    final t = entry.text;
    final r = entry.rating;
    if (_textController.text == t && _rating == r) return;
    setState(() {
      _textController.text = t;
      _rating = r;
    });
  }

  static bool _hasPersistedContent(Entry? e) {
    if (e == null) return false;
    return e.text.trim().isNotEmpty || e.rating > 0;
  }

  static bool _isEditingPersistedEntry(
    Entry? server,
    String draftText,
    int draftRating,
  ) {
    if (!_hasPersistedContent(server)) return false;
    return server!.text.trim() != draftText.trim() ||
        server.rating != draftRating;
  }

  Future<void> _addPhoto() async {
    try {
      final paths = await pickEntryPhotoPaths(context);
      if (paths.isEmpty) return;

      setState(() => _uploadTasks++);
      final repo = ref.read(entriesRepositoryProvider);
      await repo.addTodayImages(filePaths: paths);
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
      final repo = ref.read(entriesRepositoryProvider);
      await repo.addTodayMusic(input: input);
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

  Future<void> _onSave() async {
    final isvalid = _formKey.currentState?.validate() ?? false;
    if (!isvalid) return;
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating (1–5).')),
      );
      return;
    }

    final trimmed = _textController.text.trim();
    final server = switch (ref.read(entryByDateIdProvider(_activeDateId))) {
      AsyncData(:final value) => value,
      _ => null,
    };

    if (_isEditingPersistedEntry(server, trimmed, _rating)) {
      final confirm = await showAppConfirmDialog(
        context: context,
        title: 'Update entry?',
        contentText:
            'There is already a saved entry for this day. '
            'Save your changes and replace it?',
        confirmLabel: 'Save',
      );
      if (!mounted) return;
      if (confirm != true) return;
    }

    try {
      final repo = ref.read(entriesRepositoryProvider);

      setState(() => _saving = true);

      await repo.upsertTodayEntry(text: trimmed, rating: _rating);

      if (!mounted) return;
      setState(() => _draftDirty = false);
      await showEntrySavedAndNavigate(
        context,
        onComplete: () => widget.onEntrySaved?.call(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
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

      final repo = ref.read(entriesRepositoryProvider);
      await repo.addTodayLocation(
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
    // If midnight passed while app was open/resumed, switch to the new day.
    final nowDayId = EntriesRepository.dateId(DateTime.now());
    if (nowDayId != _activeDateId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _activeDateId = nowDayId;
          _draftDirty = false;
          _textController.clear();
          _rating = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'New calendar day — you are now writing for today. '
              'Earlier days stay below; you can still edit them anytime.',
            ),
          ),
        );
      });
    }

    ref.listen<AsyncValue<Entry?>>(entryByDateIdProvider(_activeDateId), (
      prev,
      next,
    ) {
      next.when(
        data: (entry) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _applyRemoteEntry(entry);
          });
        },
        loading: () {},
        error: (_, _) {},
      );
    });

    final entryAsync = ref.watch(entryByDateIdProvider(_activeDateId));

    return Scaffold(
      body: SafeArea(
        child: entryAsync.when(
          loading: () => const Center(child: AppLoadingPlaceholder.home()),
          error: (e, _) => AppErrorState(
            error: e,
            title: 'Couldn’t load today’s entry',
            onRetry: () => ref.invalidate(entryByDateIdProvider(_activeDateId)),
          ),
          data: (entry) {
            return FadeInAppear(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          entry == null
                              ? 'Write your first entry for today'
                              : 'Today entry',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatJournalDateId(_activeDateId),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        Card.outlined(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Reflection prompts',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '• What moment stood out — good or hard?',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '• What would you tell a friend about today?',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
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
                            validator: (value) => value?.isEmpty ?? true
                                ? 'Please enter your entry'
                                : null,
                          ),
                        ),
                        if (entry != null && entry.imageSources.isNotEmpty) ...[
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
                                          'This photo will be removed '
                                          'from today\'s entry.',
                                      remove: () => ref
                                          .read(entriesRepositoryProvider)
                                          .removeImageForDateId(
                                            dateId: _activeDateId,
                                            imageUrl: url,
                                          ),
                                    );
                                  },
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (entry != null && entry.imageSources.isNotEmpty)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AttachmentToolbarIcon(
                                icon: Icons.music_note_outlined,
                                tooltip: 'Add music',
                                enabled: true,
                                onPressed: _addMusic,
                              ),
                              const SizedBox(width: 10),
                              AttachmentToolbarIcon(
                                icon: Icons.add_photo_alternate_outlined,
                                tooltip: 'Add photos',
                                enabled: true,
                                onPressed: _addPhoto,
                              ),
                              const SizedBox(width: 10),
                              AttachmentToolbarIcon(
                                icon: Icons.location_on_outlined,
                                tooltip: 'Add location',
                                enabled: true,
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
                                enabled: true,
                                onPressed: _addMusic,
                              ),
                              const SizedBox(width: 12),
                              AttachmentIconTile(
                                icon: Icons.location_on_outlined,
                                enabled: true,
                                onPressed: _addLocation,
                              ),
                              const SizedBox(width: 12),
                              AttachmentIconTile(
                                icon: Icons.add_photo_alternate_outlined,
                                enabled: true,
                                onPressed: _addPhoto,
                              ),
                            ],
                          ),
                        if (entry != null && entry.files.isNotEmpty) ...[
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
                                            '“${f.name}” will be removed '
                                            'from today\'s entry.',
                                        remove: () => ref
                                            .read(entriesRepositoryProvider)
                                            .removeFileForDateId(
                                              dateId: _activeDateId,
                                              file: f,
                                            ),
                                      ),
                              ),
                            ),
                        ],
                        if (entry != null && entry.music != null) ...[
                          const SizedBox(height: 12),
                          EntryMusicCard(
                            music: entry.music!,
                            onLongPress: _uploading
                                ? null
                                : () => _confirmAndRemoveAttachment(
                                    title: 'Remove music?',
                                    contentText:
                                        'Music will be removed from '
                                        'today\'s entry.',
                                    remove: () => ref
                                        .read(entriesRepositoryProvider)
                                        .removeMusicForDateId(_activeDateId),
                                  ),
                          ),
                        ],
                        if (entry != null && entry.location != null) ...[
                          const SizedBox(height: 12),
                          EntryLocationChip(
                            location: entry.location!,
                            onLongPress: _uploading
                                ? null
                                : () => _confirmAndRemoveAttachment(
                                    title: 'Remove location?',
                                    contentText:
                                        'Location will be removed from '
                                        'today\'s entry.',
                                    remove: () => ref
                                        .read(entriesRepositoryProvider)
                                        .removeLocationForDateId(_activeDateId),
                                  ),
                          ),
                        ],
                        if (entry != null &&
                            (entry.imageSources.isNotEmpty ||
                                entry.files.isNotEmpty ||
                                entry.music != null ||
                                entry.location != null)) ...[
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
                        const SizedBox(height: 16),
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
                          onPressed: _saving ? null : _onSave,
                          child: Text(_saving ? 'Saving...' : 'Save'),
                        ),
                        const SizedBox(height: 12),
                        ref
                            .watch(recentPastEntriesProvider)
                            .when(
                              skipLoadingOnReload: true,
                              data: (past) {
                                if (past.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Theme(
                                  data: Theme.of(
                                    context,
                                  ).copyWith(dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    tilePadding: EdgeInsets.zero,
                                    initiallyExpanded: false,
                                    title: Text(
                                      'Earlier entries',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    subtitle: Text(
                                      '${past.length} days · tap to open',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                    children: [
                                      for (final e in past)
                                        ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 4,
                                              ),
                                          leading: CircleAvatar(
                                            radius: 18,
                                            child: Text(
                                              e.rating > 0
                                                  ? '${e.rating}'
                                                  : '—',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          title: Text(
                                            formatJournalDateId(e.dateId),
                                          ),
                                          subtitle: Text(
                                            _entryPreviewTitle(e),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          trailing: const Icon(
                                            Icons.chevron_right,
                                          ),
                                          onTap: () {
                                            Navigator.of(context).push(
                                              appDetailRoute(
                                                PastEntryEditScreen(
                                                  dateId: e.dateId,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                );
                              },
                              loading: () => const SizedBox.shrink(),
                              error: (e, _) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: AppErrorState(
                                  error: e,
                                  title: 'Couldn’t load earlier entries',
                                  onRetry: () =>
                                      ref.invalidate(recentPastEntriesProvider),
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
