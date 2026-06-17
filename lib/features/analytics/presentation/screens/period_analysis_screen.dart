import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/formatting/journal_date_format.dart';
import '../../../../core/navigation/app_page_routes.dart';
import '../../../../shared/app_motion_widgets.dart';
import '../../../../shared/typewriter_text.dart';
import '../../../../shared/ui_feedback.dart';
import '../../../calendar/presentation/screens/day_details_screen.dart';
import '../../../journal/domain/entities/entry.dart';
import '../../../journal/presentation/providers/entries_providers.dart';
import '../../domain/entities/period_analysis.dart';
import '../../domain/services/ai_service.dart';
import '../../domain/utils/period_utils.dart';
import '../providers/ai_providers.dart';
import '../providers/analytics_providers.dart';

final _periodEntriesProvider = StreamProvider.family<List<Entry>, PeriodRange>((
  ref,
  range,
) {
  final repo = ref.watch(entriesRepositoryProvider);
  return repo.watchEntriesForRange(from: range.from, to: range.to);
});

final _periodAnalysisProvider = StreamProvider.family<PeriodAnalysis?, String>((
  ref,
  analysisId,
) {
  final repo = ref.watch(periodAnalysisRepositoryProvider);
  return repo.watchAnalysis(analysisId);
});

class PeriodAnalysisScreen extends ConsumerStatefulWidget {
  const PeriodAnalysisScreen({
    super.key,
    required this.periodType,
    required this.range,
  });

  final PeriodType periodType;
  final PeriodRange range;

  @override
  ConsumerState<PeriodAnalysisScreen> createState() =>
      _PeriodAnalysisScreenState();
}

class _PeriodAnalysisScreenState extends ConsumerState<PeriodAnalysisScreen> {
  bool _apiCallInFlight = false;

  /// Hides stale summary until Firestore delivers new text after Regenerate.
  bool _waitingForNewSummary = false;
  String? _summaryBeforeRegenerate;
  DateTime? _createdAtBeforeRegenerate;

  bool _animateNextSummary = false;
  Key _typewriterKey = UniqueKey();

  Future<void> _generate({required bool force}) async {
    final range = widget.range;

    final entriesAsync = ref.read(_periodEntriesProvider(range));
    final entries = switch (entriesAsync) {
      AsyncData(:final value) => value,
      _ => const <Entry>[],
    };

    if (entries.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No entries in this period.')),
      );
      return;
    }

    if (!force) return;

    final current = ref.read(_periodAnalysisProvider(range.id)).asData?.value;
    final currentSummary = current?.summary.trim() ?? '';
    final hadSummary = currentSummary.isNotEmpty;

    try {
      setState(() {
        _apiCallInFlight = true;
        _waitingForNewSummary = true;
        _summaryBeforeRegenerate = currentSummary;
        _createdAtBeforeRegenerate = current?.createdAt;
        _animateNextSummary = false;
      });

      final ai = ref.read(aiServiceProvider);
      await ai.analyzePeriod(
        PeriodAiInput(
          periodId: range.id,
          periodType: widget.periodType == PeriodType.week ? 'week' : 'month',
          fromDateId: range.fromDateId,
          toDateId: range.toDateId,
          force: true,
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hadSummary ? 'Regenerate requested.' : 'Generate requested.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _waitingForNewSummary = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _apiCallInFlight = false);
    }
  }

  void _onAnalysisUpdated(PeriodAnalysis? analysis) {
    if (!_waitingForNewSummary || analysis == null) return;
    final summary = analysis.summary.trim();
    if (summary.isEmpty) return;

    final createdAt = analysis.createdAt;
    final textChanged = summary != _summaryBeforeRegenerate;
    final timeChanged =
        createdAt != null && createdAt != _createdAtBeforeRegenerate;
    if (!textChanged && !timeChanged) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _waitingForNewSummary = false;
        _animateNextSummary = true;
        _typewriterKey = UniqueKey();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final range = widget.range;
    final entriesAsync = ref.watch(_periodEntriesProvider(range));
    final analysisAsync = ref.watch(_periodAnalysisProvider(range.id));

    ref.listen<AsyncValue<PeriodAnalysis?>>(
      _periodAnalysisProvider(range.id),
      (_, next) => _onAnalysisUpdated(next.asData?.value),
    );

    final analysis = analysisAsync.asData?.value;
    final summary = analysis?.summary.trim() ?? '';
    final hasSavedSummary =
        analysis != null &&
        summary.isNotEmpty &&
        summary != 'No entries in this period.';
    final showWriting =
        _waitingForNewSummary || (_apiCallInFlight && !hasSavedSummary);
    final showSummary =
        hasSavedSummary && !_waitingForNewSummary && !showWriting;

    return Scaffold(
      appBar: AppBar(title: Text(range.label)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.periodType == PeriodType.week
                    ? 'Weekly summary'
                    : 'Monthly summary',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Range: ${formatJournalDateRange(range.fromDateId, range.toDateId)}',
              ),
              const SizedBox(height: 16),
              entriesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: SkeletonBox(height: 120),
                ),
                error: (e, _) => AppErrorState(
                  error: e,
                  title: 'Couldn’t load days in this period',
                  onRetry: () => ref.invalidate(_periodEntriesProvider(range)),
                ),
                data: (entries) {
                  final ids = entries.map((e) => e.dateId).toSet().toList()
                    ..sort();
                  if (ids.isEmpty) {
                    return const AppEmptyState(
                      icon: Icons.calendar_view_month_outlined,
                      title: 'No journal days in this range',
                      subtitle:
                          'Write entries on Home for dates inside this week or month, then try again.',
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Days included',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final id in ids)
                            ActionChip(
                              label: Text(formatJournalDateId(id)),
                              onPressed: () {
                                Navigator.of(context).push(
                                  appDetailRoute(DayDetailsScreen(dateId: id)),
                                );
                              },
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              if (analysisAsync.isLoading && analysis == null)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: SkeletonBox(height: 120),
                )
              else if (analysisAsync.hasError)
                AppErrorState(
                  error: analysisAsync.error!,
                  title: 'Couldn’t load analysis',
                  onRetry: () =>
                      ref.invalidate(_periodAnalysisProvider(range.id)),
                )
              else if (!hasSavedSummary && !showWriting) ...[
                const AppEmptyState(
                  icon: Icons.auto_awesome_outlined,
                  title: 'No AI summary yet',
                  subtitle:
                      'Generate a warm reflection for this period from your journal entries.',
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _apiCallInFlight
                      ? null
                      : () => _generate(force: true),
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(_apiCallInFlight ? 'Working…' : 'Generate'),
                ),
              ] else ...[
                if (showWriting) ...[
                  const AiWritingIndicator(),
                  const SizedBox(height: 16),
                ],
                if (showSummary) ...[
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: _apiCallInFlight
                            ? null
                            : () => _generate(force: true),
                        icon: const Icon(Icons.refresh),
                        label: Text(
                          _apiCallInFlight ? 'Working…' : 'Regenerate',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'AI summary',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TypewriterText(
                    key: _typewriterKey,
                    text: summary,
                    animate: _animateNextSummary,
                    lineDelay: const Duration(milliseconds: 110),
                    onFinished: () {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        setState(() => _animateNextSummary = false);
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Model: ${analysis.model}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _apiCallInFlight
                    ? null
                    : () => Navigator.of(context).pop(),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
