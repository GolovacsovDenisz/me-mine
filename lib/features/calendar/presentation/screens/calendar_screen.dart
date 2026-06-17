import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/motion/app_motion.dart';
import '../../../../core/navigation/app_page_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shape.dart';
import '../../../../shared/app_motion_widgets.dart';
import '../../../../shared/entry_attachments_ui.dart';
import '../../../../shared/ui_feedback.dart';
import '../../../journal/domain/entities/entry.dart';
import '../../../journal/domain/utils/journal_date_utils.dart';
import '../../domain/utils/calendar_entry_utils.dart';
import '../providers/calendar_providers.dart';
import '../widgets/staggered_calendar_grid.dart';
import 'day_details_screen.dart';
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  String? _selectedDateId;

  void _goPrevMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
      _selectedDateId = null;
    });
  }

  void _goNextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
      _selectedDateId = null;
    });
  }

  /// Swipe right → previous month; swipe left → next month.
  void _onMonthSwipe(DragEndDetails details) {
    const minVelocity = 280;
    final v = details.primaryVelocity ?? 0;
    if (v > minVelocity) {
      HapticFeedback.selectionClick();
      _goPrevMonth();
    } else if (v < -minVelocity) {
      HapticFeedback.selectionClick();
      _goNextMonth();
    }
  }

  Future<void> _openDay(String dateId) async {
    setState(() => _selectedDateId = dateId);
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push<void>(appDetailRoute(DayDetailsScreen(dateId: dateId)));
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(monthEntriesProvider(_focusedMonth));
    final todayId = JournalDateUtils.dateId(DateTime.now());

    return entriesAsync.when(
      loading: () => const AppLoadingPlaceholder.calendar(),
      error: (e, _) => AppErrorState(
        error: e,
        title: 'Couldn’t load this month',
        onRetry: () => ref.invalidate(monthEntriesProvider(_focusedMonth)),
      ),
      data: (entries) {
        final byDateId = <String, Entry>{for (final e in entries) e.dateId: e};

        final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
        final lastDay = DateTime(
          _focusedMonth.year,
          _focusedMonth.month + 1,
          0,
        );

        final firstWeekday = firstDay.weekday;
        final leadingEmpty = firstWeekday - DateTime.monday;
        final totalDays = lastDay.day;
        final totalCells = ((leadingEmpty + totalDays) <= 35) ? 35 : 42;

        final monthLabel = _monthLabel(_focusedMonth);

        return GestureDetector(
          onHorizontalDragEnd: _onMonthSwipe,
          behavior: HitTestBehavior.opaque,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _goPrevMonth,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: AppMotion.fast,
                        switchInCurve: AppMotion.enter,
                        child: Text(
                          monthLabel,
                          key: ValueKey(monthLabel),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _goNextMonth,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _WeekdayLabel('Mon'),
                    _WeekdayLabel('Tue'),
                    _WeekdayLabel('Wed'),
                    _WeekdayLabel('Thu'),
                    _WeekdayLabel('Fri'),
                    _WeekdayLabel('Sat'),
                    _WeekdayLabel('Sun'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: GridView.builder(
                    key: ValueKey(
                      '${_focusedMonth.year}-${_focusedMonth.month}',
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                    itemCount: totalCells,
                    itemBuilder: (context, index) {
                      final dayNumber = index - leadingEmpty + 1;
                      if (dayNumber < 1 || dayNumber > totalDays) {
                        return const SizedBox.shrink();
                      }

                      final dayDate = DateTime(
                        _focusedMonth.year,
                        _focusedMonth.month,
                        dayNumber,
                      );
                      final dateId = JournalDateUtils.dateId(dayDate);
                      final entry = byDateId[dateId];
                      final hasEntry = calendarDayHasEntry(entry);
                      final hasAttachment = calendarDayHasAttachment(entry);
                      final thumbUrl = (entry?.imageSources.isNotEmpty ?? false)
                          ? entry!.imageSources.first
                          : null;
                      final isToday = dateId == todayId;
                      final isSelected = _selectedDateId == dateId;

                      return StaggeredEntrance(
                        key: ValueKey(dateId),
                        index: index,
                        child: _DayCell(
                          dayNumber: dayNumber,
                          hasEntry: hasEntry,
                          hasAttachment: hasAttachment,
                          isToday: isToday,
                          isSelected: isSelected,
                          thumbnailUrl: thumbUrl,
                          onTap: () => _openDay(dateId),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _monthLabel(DateTime month) {
  const names = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final name = names[month.month - 1];
  return '$name ${month.year}';
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.dayNumber,
    required this.hasEntry,
    required this.hasAttachment,
    required this.isToday,
    required this.isSelected,
    required this.thumbnailUrl,
    required this.onTap,
  });

  final int dayNumber;
  final bool hasEntry;
  final bool hasAttachment;
  final bool isToday;
  final bool isSelected;
  final String? thumbnailUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final surface = scheme.surface;

    Color borderColor;
    double borderWidth;
    if (isSelected) {
      borderColor = hasAttachment ? AppColors.success : AppColors.danger;
      borderWidth = 2.5;
    } else if (isToday) {
      borderColor = scheme.primary;
      borderWidth = 2;
    } else if (hasEntry) {
      borderColor = scheme.onSurface;
      borderWidth = 2;
    } else {
      borderColor = scheme.outline;
      borderWidth = 1;
    }

    final todayFill = isToday && !isSelected && thumbnailUrl == null;

    final dayStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: thumbnailUrl == null
          ? (todayFill ? scheme.onPrimary : scheme.onSurface)
          : Colors.white,
    );

    return GestureDetector(
      onTap: onTap,
      child: Material(
        color: thumbnailUrl == null
            ? (todayFill ? scheme.primary : surface)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppShape.radiusMd,
          side: BorderSide(color: borderColor, width: borderWidth),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (thumbnailUrl != null)
              EntryImage(
                source: thumbnailUrl!,
                fit: BoxFit.cover,
                errorWidget: const SizedBox.shrink(),
              ),
            if (thumbnailUrl == null)
              Center(child: Text('$dayNumber', style: dayStyle))
            else
              Positioned(
                top: 4,
                left: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    child: Text(
                      '$dayNumber',
                      style: dayStyle?.copyWith(fontSize: 11),
                    ),
                  ),
                ),
              ),
            if (isToday && !isSelected && thumbnailUrl == null)
              Positioned(
                bottom: 4,
                left: 0,
                right: 0,
                child: Text(
                  'Add',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
