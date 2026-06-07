import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting/journal_date_format.dart';
import '../../core/navigation/app_page_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/entry_attachments_ui.dart';
import '../../shared/ui_feedback.dart';
import '../home/entries_repository.dart';
import '../home/past_entry_edit_screen.dart';

class DayDetailsScreen extends ConsumerStatefulWidget {
  const DayDetailsScreen({super.key, required this.dateId});

  final String dateId;

  @override
  ConsumerState<DayDetailsScreen> createState() => _DayDetailsScreenState();
}

class _DayDetailsScreenState extends ConsumerState<DayDetailsScreen> {
  final _scrollController = ScrollController();
  double _headerBlur = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final px = _scrollController.offset;
    final sigma = (px / 28).clamp(0.0, 10.0);
    if ((sigma - _headerBlur).abs() < 0.05) return;
    setState(() => _headerBlur = sigma);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openEditor() async {
    await Navigator.of(
      context,
    ).push<void>(appDetailRoute(PastEntryEditScreen(dateId: widget.dateId)));
  }

  @override
  Widget build(BuildContext context) {
    final entryAsync = ref.watch(entryByDateIdProvider(widget.dateId));

    return Scaffold(
      appBar: AppBar(
        title: Text(formatJournalDateId(widget.dateId)),
        actions: [
          TextButton.icon(
            onPressed: entryAsync.maybeWhen(
              data: (e) => e != null ? _openEditor : null,
              orElse: () => null,
            ),
            icon: const Icon(Icons.edit_outlined, size: 20),
            label: const Text('Edit'),
          ),
        ],
      ),
      body: SafeArea(
        child: entryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => AppErrorState(
            error: e,
            title: 'Couldn’t load this day',
            onRetry: () => ref.invalidate(entryByDateIdProvider(widget.dateId)),
          ),
          data: (entry) {
            if (entry == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AppEmptyState(
                          icon: Icons.event_note_outlined,
                          title: 'No entry for this day',
                          subtitle:
                              'You can add text, photos, location, and music for this day.',
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _openEditor,
                          icon: const Icon(Icons.add),
                          label: const Text('Add entry'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            final heroUrl = entry.imageSources.isNotEmpty
                ? entry.imageSources.first
                : null;

            return CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                if (heroUrl != null)
                  SliverToBoxAdapter(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(20),
                      ),
                      child: SizedBox(
                        height: 240,
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(
                            sigmaX: _headerBlur,
                            sigmaY: _headerBlur,
                            tileMode: TileMode.decal,
                          ),
                          child: EntryImage(
                            source: heroUrl,
                            height: 240,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorWidget: Container(
                              height: 240,
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image, size: 48),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (entry.rating > 0)
                        Row(
                          children: [
                            Text(
                              'Mood',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(width: 8),
                            ...List.generate(
                              5,
                              (i) => Icon(
                                i < entry.rating
                                    ? Icons.star
                                    : Icons.star_border,
                                size: 22,
                                color: i < entry.rating
                                    ? AppColors.star
                                    : AppColors.lineStrong,
                              ),
                            ),
                          ],
                        ),
                      if (entry.rating > 0) const SizedBox(height: 12),
                      Text(
                        entry.text,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                      if (entry.imageSources.length > 1) ...[
                        Text(
                          'More photos',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 100,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: entry.imageSources.length - 1,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              final url = entry.imageSources[i + 1];
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: AspectRatio(
                                  aspectRatio: 1,
                                  child: EntryImage(
                                    source: url,
                                    fit: BoxFit.cover,
                                    errorWidget: const Icon(Icons.broken_image),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (entry.music != null) ...[
                        Text(
                          'Music',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        EntryMusicPlayer(music: entry.music!),
                        const SizedBox(height: 16),
                      ],
                      if (entry.files.isNotEmpty) ...[
                        Text(
                          'Files',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        for (final f in entry.files)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: const Icon(Icons.insert_drive_file),
                            title: Text(f.name),
                            subtitle: Text(
                              '${(f.sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB',
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
                      if (entry.location != null) ...[
                        Text(
                          'Location',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: const Icon(Icons.location_on),
                          title: Text(
                            '${entry.location!.lat.toStringAsFixed(5)}, '
                            '${entry.location!.lng.toStringAsFixed(5)}',
                          ),
                          subtitle: Text(
                            'Accuracy: '
                            '${entry.location!.accuracyMeters.toStringAsFixed(0)} m',
                          ),
                        ),
                      ],
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
