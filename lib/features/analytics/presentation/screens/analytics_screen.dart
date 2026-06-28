import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/formatting/journal_date_format.dart';
import '../../../../core/navigation/app_page_routes.dart';
import '../../../../core/theme/app_shape.dart';
import '../../../../shared/app_motion_widgets.dart';
import '../../../../shared/ui_feedback.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../journal/domain/entities/entry.dart';
import '../../domain/entities/period_analysis.dart';
import '../../domain/utils/analytics_weekly_stats.dart';
import '../../domain/utils/period_utils.dart';
import '../../../journal/presentation/providers/entries_providers.dart';
import '../providers/analytics_providers.dart';
import 'period_analysis_screen.dart';

final _analysisByIdProvider = StreamProvider.family<PeriodAnalysis?, String>((
  ref,
  analysisId,
) {
  final repo = ref.watch(periodAnalysisRepositoryProvider);
  return repo.watchAnalysis(analysisId);
});

final _entriesForRangeProvider =
    StreamProvider.family<List<Entry>, PeriodRange>((ref, range) {
      final repo = ref.watch(entriesRepositoryProvider);
      return repo.watchEntriesForRange(from: range.from, to: range.to);
    });

enum AnalyticsGranularity { day, week, month }

/// Loads entries from the earliest point needed for day / week / month charts.
final analyticsChartEntriesProvider = StreamProvider<List<Entry>>((ref) {
  final repo = ref.watch(entriesRepositoryProvider);
  final now = DateTime.now();
  final from = analyticsEntriesRangeStart(now: now);
  return repo.watchEntriesForRange(from: from, to: now);
});

List<Entry> _entriesLast30Days(List<Entry> all, DateTime now) {
  final cutoff = dateOnly(now.subtract(const Duration(days: 29)));
  return all
      .where((e) {
        try {
          return !parseDateId(e.dateId).isBefore(cutoff);
        } on FormatException {
          return false;
        }
      })
      .toList(growable: false);
}

List<RatingBarPoint> _pointsForGranularity(
  List<Entry> entries,
  AnalyticsGranularity g,
  DateTime now, {
  String? locale,
}) {
  switch (g) {
    case AnalyticsGranularity.day:
      return computeDailyRatings(
        entries,
        dayCount: 30,
        now: now,
        locale: locale,
      );
    case AnalyticsGranularity.week:
      return weeklyStatsToBarPoints(
        computeWeeklyAverages(entries, weekCount: 12, now: now),
        locale: locale,
      );
    case AnalyticsGranularity.month:
      return monthlyStatsToBarPoints(
        computeMonthlyAverages(entries, monthCount: 12, now: now),
        locale: locale,
      );
  }
}

(String title, String subtitle) _chartCopy(AnalyticsGranularity g) {
  switch (g) {
    case AnalyticsGranularity.day:
      return (
        'Daily mood',
        'Star rating per day (last 30 days). Zero bar = no rating.',
      );
    case AnalyticsGranularity.week:
      return (
        'Weekly mood',
        'Average rating per week (Mon–Sun), last 12 weeks.',
      );
    case AnalyticsGranularity.month:
      return (
        'Monthly mood',
        'Average rating per calendar month, last 12 months.',
      );
  }
}

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  AnalyticsGranularity _granularity = AnalyticsGranularity.week;

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(analyticsChartEntriesProvider);

    return entriesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: AppLoadingPlaceholder.analytics(),
      ),
      error: (e, _) => AppErrorState(
        error: e,
        title: 'Couldn’t load analytics',
        onRetry: () => ref.invalidate(analyticsChartEntriesProvider),
      ),
      data: (entries) {
        final now = DateTime.now();
        final locale = journalDisplayLocale();
        final last30 = _entriesLast30Days(entries, now);
        final points = _pointsForGranularity(
          entries,
          _granularity,
          now,
          locale: locale,
        );

        final rated = last30.where((e) => e.rating > 0).toList();
        final count = rated.length;
        final sum = rated.fold<int>(0, (acc, e) => acc + e.rating);
        final avg30 = count == 0 ? 0.0 : sum / count;

        if (entries.isEmpty) {
          return const AppEmptyState(
            icon: Icons.insights_outlined,
            title: 'No entries in this range yet',
            subtitle:
                'Save a few days on Home with a star rating, then open Analytics again.',
          );
        }

        final theme = Theme.of(context);
        final primary = theme.colorScheme.primary;
        final (chartTitle, chartSubtitle) = _chartCopy(_granularity);

        return FadeInAppear(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(chartTitle, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                chartSubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: SegmentedButton<AnalyticsGranularity>(
                  segments: const [
                    ButtonSegment(
                      value: AnalyticsGranularity.day,
                      label: Text('Day'),
                      icon: Icon(Icons.calendar_view_day, size: 18),
                    ),
                    ButtonSegment(
                      value: AnalyticsGranularity.week,
                      label: Text('Week'),
                      icon: Icon(Icons.view_week, size: 18),
                    ),
                    ButtonSegment(
                      value: AnalyticsGranularity.month,
                      label: Text('Month'),
                      icon: Icon(Icons.calendar_month, size: 18),
                    ),
                  ],
                  emptySelectionAllowed: false,
                  selected: {_granularity},
                  onSelectionChanged: (next) {
                    setState(() => _granularity = next.first);
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: math.max(240.0, 48.0 + points.length * 28.0),
                child: _HorizontalScrollableRatingChart(
                  key: ValueKey(_granularity),
                  points: points,
                  barColor: primary,
                  textTheme: theme.textTheme,
                ),
              ),
              const SizedBox(height: 24),
              Text('AI summaries', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Tap a card to generate or view. Analysis is saved and only '
                'changes when you regenerate manually.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              _PeriodCardsSection(
                title: 'Weeks',
                ranges: [
                  for (var i = 0; i < 4; i++) weekRangeFromOffset(weeksAgo: i),
                ],
                periodType: PeriodType.week,
              ),
              const SizedBox(height: 12),
              _PeriodCardsSection(
                title: 'Months',
                ranges: [
                  for (var i = 0; i < 4; i++)
                    monthRangeFromOffset(monthsAgo: i),
                ],
                periodType: PeriodType.month,
              ),
              const SizedBox(height: 24),
              Text('Last 30 days', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                count == 0
                    ? 'Average rating: — (no rated days in this window)'
                    : 'Average rating: ${avg30.toStringAsFixed(2)} / 5.0 '
                          '($count days with stars)',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Text('By day', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              for (final e in last30)
                ListTile(
                  dense: true,
                  title: Text(formatJournalDateId(e.dateId, locale: locale)),
                  subtitle: e.text.isNotEmpty
                      ? Text(
                          e.text.length > 60
                              ? '${e.text.substring(0, 60)}…'
                              : e.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  trailing: Text(
                    e.rating > 0 ? '${e.rating}/5' : '—',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Owns a [ScrollController] tied to this horizontal [Scrollbar] / scroll view
/// so rebuilds of the parent [ListView] cannot leave a stale controller attached.
class _HorizontalScrollableRatingChart extends StatefulWidget {
  const _HorizontalScrollableRatingChart({
    super.key,
    required this.points,
    required this.barColor,
    required this.textTheme,
  });

  final List<RatingBarPoint> points;
  final Color barColor;
  final TextTheme textTheme;

  @override
  State<_HorizontalScrollableRatingChart> createState() =>
      _HorizontalScrollableRatingChartState();
}

class _HorizontalScrollableRatingChartState
    extends State<_HorizontalScrollableRatingChart> {
  late final ScrollController _hScroll;

  @override
  void initState() {
    super.initState();
    _hScroll = ScrollController();
  }

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    return LayoutBuilder(
      builder: (context, constraints) {
        final chartWidth = math.max(
          constraints.maxWidth,
          points.length * 44.0 + 48,
        );
        return Scrollbar(
          controller: _hScroll,
          thumbVisibility: points.length > 8,
          child: SingleChildScrollView(
            controller: _hScroll,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: chartWidth,
              height: constraints.maxHeight,
              child: _RatingBarChart(
                points: points,
                barColor: widget.barColor,
                textTheme: widget.textTheme,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PeriodCardsSection extends ConsumerStatefulWidget {
  const _PeriodCardsSection({
    required this.title,
    required this.ranges,
    required this.periodType,
  });

  final String title;
  final List<PeriodRange> ranges;
  final PeriodType periodType;

  @override
  ConsumerState<_PeriodCardsSection> createState() =>
      _PeriodCardsSectionState();
}

class _PeriodCardsSectionState extends ConsumerState<_PeriodCardsSection>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _expandCtrl;
  late final Animation<double> _expandCurve;

  @override
  void initState() {
    super.initState();
    _expandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _expandCurve = CurvedAnimation(
      parent: _expandCtrl,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _expandCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _expandCtrl.forward(from: 0);
    } else {
      _expandCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: scheme.surfaceContainerHighest,
          borderRadius: AppShape.radiusMd,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _toggle,
            borderRadius: AppShape.radiusMd,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Text(widget.title, style: theme.textTheme.titleMedium),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOut,
                    child: Icon(
                      Icons.expand_more,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ClipRect(
          child: SizeTransition(
            axisAlignment: -1,
            sizeFactor: _expandCurve,
            child: FadeTransition(
              opacity: _expandCurve,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.8,
                  children: [
                    for (var i = 0; i < widget.ranges.length; i++)
                      _StaggeredPeriodCard(
                        index: i,
                        animation: _expandCurve,
                        child: _PeriodCard(
                          range: widget.ranges[i],
                          periodType: widget.periodType,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StaggeredPeriodCard extends StatelessWidget {
  const _StaggeredPeriodCard({
    required this.index,
    required this.animation,
    required this.child,
  });

  final int index;
  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final start = (index * 0.12).clamp(0.0, 0.55);
        final end = (start + 0.55).clamp(0.0, 1.0);
        final t = Curves.easeOutCubic.transform(
          Interval(start, end).transform(animation.value),
        );
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, -28 * (1 - t)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _PeriodCard extends ConsumerWidget {
  const _PeriodCard({required this.range, required this.periodType});

  final PeriodRange range;
  final PeriodType periodType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysisAsync = ref.watch(_analysisByIdProvider(range.id));
    final entriesAsync = ref.watch(_entriesForRangeProvider(range));

    final hasEntries = entriesAsync.maybeWhen(
      data: (v) => v.isNotEmpty,
      orElse: () => false,
    );

    final analysis = analysisAsync.maybeWhen(
      data: (v) => v,
      orElse: () => null,
    );

    final status = analysis != null
        ? 'Ready'
        : hasEntries
        ? 'Tap to generate'
        : 'No data';

    final locale = journalDisplayLocale();

    return InkWell(
      borderRadius: AppShape.radiusMd,
      onTap: () {
        Navigator.of(context).push(
          appDetailRoute(
            PeriodAnalysisScreen(periodType: periodType, range: range),
          ),
        );
      },
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: AppShape.radiusMd,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formatJournalDateId(range.fromDateId, locale: locale),
              style: Theme.of(context).textTheme.labelLarge,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              formatJournalDateId(range.toDateId, locale: locale),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              children: [
                Icon(
                  analysis != null ? Icons.check_circle : Icons.auto_awesome,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    status,
                    style: Theme.of(context).textTheme.labelMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingBarChart extends StatelessWidget {
  const _RatingBarChart({
    required this.points,
    required this.barColor,
    required this.textTheme,
  });

  final List<RatingBarPoint> points;
  final Color barColor;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 5,
        minY: 0,
        groupsSpace: 8,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) =>
                Theme.of(context).colorScheme.inverseSurface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final i = group.x.toInt();
              if (i < 0 || i >= points.length) return null;
              final p = points[i];
              final unit = p.ratedCount == 1 ? 'day' : 'days';
              return BarTooltipItem(
                '${p.value.toStringAsFixed(2)} · '
                '${p.ratedCount} rated $unit',
                textTheme.labelSmall!.copyWith(
                  color: Theme.of(context).colorScheme.onInverseSurface,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value != value.roundToDouble()) {
                  return const SizedBox.shrink();
                }
                final v = value.toInt();
                if (v < 0 || v > 5) return const SizedBox.shrink();
                return Text('$v', style: textTheme.labelSmall);
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= points.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(points[i].label, style: textTheme.labelSmall),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: points[i].value,
                  color: barColor.withValues(
                    alpha: points[i].ratedCount > 0 ? 1 : 0.35,
                  ),
                  width: 18,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: 5,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
