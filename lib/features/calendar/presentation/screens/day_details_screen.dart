import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/formatting/journal_date_format.dart';
import '../../../../core/navigation/app_page_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/entry_attachments_ui.dart';
import '../../../../shared/ui_feedback.dart';
import '../../../journal/presentation/providers/entries_providers.dart';
import '../../../journal/presentation/screens/past_entry_edit_screen.dart';

class DayDetailsScreen extends ConsumerWidget {
  const DayDetailsScreen({super.key, required this.dateId});

  final String dateId;

  Future<void> _openEditor(BuildContext context) async {
    await Navigator.of(
      context,
    ).push<void>(appDetailRoute(PastEntryEditScreen(dateId: dateId)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryAsync = ref.watch(entryByDateIdProvider(dateId));

    return Scaffold(
      appBar: AppBar(
        title: Text(formatJournalDateId(dateId)),
        actions: [
          TextButton.icon(
            onPressed: entryAsync.maybeWhen(
              data: (e) => e != null ? () => _openEditor(context) : null,
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
            onRetry: () => ref.invalidate(entryByDateIdProvider(dateId)),
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
                          onPressed: () => _openEditor(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Add entry'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            return CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (entry.imageSources.isNotEmpty) ...[
                        EntryPhotoCarousel(imageUrls: entry.imageSources),
                        if (entry.imageSources.length > 1) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Swipe photos left or right',
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
                      ],
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
                        EntryLocationChip(location: entry.location!),
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
