import '../../core/formatting/journal_date_format.dart';
import '../home/entries_repository.dart';
import 'analytics_weekly_stats.dart';

class PeriodRange {
  const PeriodRange({
    required this.id,
    required this.from,
    required this.to,
    required this.label,
    required this.fromDateId,
    required this.toDateId,
  });

  final String id;
  final DateTime from; // dateOnly
  final DateTime to; // dateOnly
  final String label;
  final String fromDateId;
  final String toDateId;
}

PeriodRange weekRangeFromOffset({required int weeksAgo, DateTime? now}) {
  final n = dateOnly(now ?? DateTime.now());
  final thisMonday = mondayOfWeekContaining(n);
  final start = dateOnly(thisMonday.subtract(Duration(days: 7 * weeksAgo)));
  final end = dateOnly(start.add(const Duration(days: 6)));
  final fromId = EntriesRepository.dateId(start);
  final toId = EntriesRepository.dateId(end);
  return PeriodRange(
    id: 'week_$fromId',
    from: start,
    to: end,
    label: formatJournalDateRange(fromId, toId),
    fromDateId: fromId,
    toDateId: toId,
  );
}

PeriodRange monthRangeFromOffset({required int monthsAgo, DateTime? now}) {
  final n = dateOnly(now ?? DateTime.now());
  final start = firstDayOfMonthMonthsAgo(monthsAgo, n);
  final end = DateTime(start.year, start.month + 1, 0);
  final from = dateOnly(start);
  final to = dateOnly(end);
  final fromId = EntriesRepository.dateId(from);
  final toId = EntriesRepository.dateId(to);
  return PeriodRange(
    id: 'month_${start.year}-${start.month.toString().padLeft(2, '0')}',
    from: from,
    to: to,
    label: formatJournalDateRange(fromId, toId),
    fromDateId: fromId,
    toDateId: toId,
  );
}
