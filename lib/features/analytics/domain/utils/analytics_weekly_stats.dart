import '../../../journal/domain/entities/entry.dart';
import '../../../journal/domain/utils/journal_date_utils.dart';

/// Calendar date without time, local conventions.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Monday 00:00 of the ISO-style week containing [day] (week starts Monday).
DateTime mondayOfWeekContaining(DateTime day) {
  final d = dateOnly(day);
  return d.subtract(Duration(days: d.weekday - DateTime.monday));
}

DateTime parseDateId(String dateId) {
  final p = dateId.split('-');
  if (p.length != 3) {
    throw FormatException('Expected yyyy-mm-dd', dateId);
  }
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// Firestore range start for charts: Monday of the oldest week in the window.
DateTime chartRangeFromMonday({required int weekCount, DateTime? now}) {
  final end = now ?? DateTime.now();
  final endMonday = mondayOfWeekContaining(end);
  return dateOnly(endMonday.subtract(Duration(days: 7 * (weekCount - 1))));
}

/// First calendar day of the month [monthsAgo] months before [anchor]'s month.
DateTime firstDayOfMonthMonthsAgo(int monthsAgo, DateTime anchor) {
  var y = anchor.year;
  var m = anchor.month - monthsAgo;
  while (m <= 0) {
    m += 12;
    y -= 1;
  }
  return DateTime(y, m, 1);
}

/// Earliest [DateTime] we need for day (30d), week (12w), and month (12×) charts.
DateTime analyticsEntriesRangeStart({DateTime? now}) {
  final n = now ?? DateTime.now();
  final dayStart = dateOnly(n.subtract(const Duration(days: 29)));
  final weekStart = chartRangeFromMonday(weekCount: 12, now: n);
  final monthStart = firstDayOfMonthMonthsAgo(11, n);
  return [
    dayStart,
    weekStart,
    monthStart,
  ].reduce((a, b) => a.isBefore(b) ? a : b);
}

/// One bar on the rating chart (day / week / month bucket).
class RatingBarPoint {
  const RatingBarPoint({
    required this.label,
    required this.value,
    required this.ratedCount,
  });

  /// Short axis label (e.g. `12/05`, `Jan 26`, `03/25`).
  final String label;

  /// Height of the bar: average rating or single-day rating; `0` … `5`.
  final double value;

  /// Days with `rating > 0` inside this bucket (for tooltip).
  final int ratedCount;
}

class WeeklyRatingStats {
  const WeeklyRatingStats({
    required this.weekStartMonday,
    required this.average,
    required this.ratedDaysCount,
  });

  final DateTime weekStartMonday;

  /// Mean of [Entry.rating] for days with `rating > 0`; `0` if none.
  final double average;
  final int ratedDaysCount;
}

/// Groups [entries] into [weekCount] consecutive weeks ending at the week containing [now].
/// Weeks are Monday–Sunday; order is **oldest → newest** (left → right on a typical chart).
List<WeeklyRatingStats> computeWeeklyAverages(
  List<Entry> entries, {
  int weekCount = 12,
  DateTime? now,
}) {
  final end = now ?? DateTime.now();
  final endMonday = dateOnly(mondayOfWeekContaining(end));

  final mondays = <DateTime>[
    for (var i = weekCount - 1; i >= 0; i--)
      dateOnly(endMonday.subtract(Duration(days: 7 * i))),
  ];

  final sumByMonday = <DateTime, int>{for (final m in mondays) m: 0};
  final countByMonday = <DateTime, int>{for (final m in mondays) m: 0};

  for (final e in entries) {
    late final DateTime day;
    try {
      day = parseDateId(e.dateId);
    } on FormatException {
      continue;
    }
    final monday = dateOnly(mondayOfWeekContaining(day));
    if (!sumByMonday.containsKey(monday)) continue;
    if (e.rating <= 0) continue;
    sumByMonday[monday] = sumByMonday[monday]! + e.rating;
    countByMonday[monday] = countByMonday[monday]! + 1;
  }

  return [
    for (final m in mondays)
      WeeklyRatingStats(
        weekStartMonday: m,
        average: (countByMonday[m] ?? 0) == 0
            ? 0
            : sumByMonday[m]! / countByMonday[m]!,
        ratedDaysCount: countByMonday[m] ?? 0,
      ),
  ];
}

String shortWeekLabel(DateTime weekStartMonday) {
  final m = weekStartMonday.month;
  final d = weekStartMonday.day;
  return '$d/${m.toString().padLeft(2, '0')}';
}

/// One calendar day per bar: rating that day, or `0` if no entry / no stars.
List<RatingBarPoint> computeDailyRatings(
  List<Entry> entries, {
  int dayCount = 30,
  DateTime? now,
}) {
  final end = dateOnly(now ?? DateTime.now());
  final days = <DateTime>[
    for (var i = dayCount - 1; i >= 0; i--) end.subtract(Duration(days: i)),
  ];

  final ratingByDateId = <String, int>{};
  for (final e in entries) {
    if (e.rating <= 0) continue;
    ratingByDateId[e.dateId] = e.rating;
  }

  return [
    for (final d in days)
      () {
        final id = JournalDateUtils.dateId(d);
        final r = ratingByDateId[id];
        return RatingBarPoint(
          label: '${d.day}/${d.month.toString().padLeft(2, '0')}',
          value: r != null ? r.toDouble() : 0,
          ratedCount: r != null ? 1 : 0,
        );
      }(),
  ];
}

class MonthlyRatingStats {
  const MonthlyRatingStats({
    required this.monthStart,
    required this.average,
    required this.ratedDaysCount,
  });

  final DateTime monthStart;
  final double average;
  final int ratedDaysCount;
}

/// Last [monthCount] calendar months (from 1st of month), oldest → newest.
List<MonthlyRatingStats> computeMonthlyAverages(
  List<Entry> entries, {
  int monthCount = 12,
  DateTime? now,
}) {
  final end = now ?? DateTime.now();

  final monthStarts = <DateTime>[
    for (var i = monthCount - 1; i >= 0; i--) firstDayOfMonthMonthsAgo(i, end),
  ];

  final sumByStart = <DateTime, int>{for (final m in monthStarts) m: 0};
  final countByStart = <DateTime, int>{for (final m in monthStarts) m: 0};

  for (final e in entries) {
    late final DateTime day;
    try {
      day = parseDateId(e.dateId);
    } on FormatException {
      continue;
    }
    final start = DateTime(day.year, day.month, 1);
    if (!sumByStart.containsKey(start)) continue;
    if (e.rating <= 0) continue;
    sumByStart[start] = sumByStart[start]! + e.rating;
    countByStart[start] = countByStart[start]! + 1;
  }

  return [
    for (final m in monthStarts)
      MonthlyRatingStats(
        monthStart: m,
        average: (countByStart[m] ?? 0) == 0
            ? 0
            : sumByStart[m]! / countByStart[m]!,
        ratedDaysCount: countByStart[m] ?? 0,
      ),
  ];
}

String shortMonthLabel(DateTime monthStart) {
  const names = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final y = monthStart.year % 100;
  return '${names[monthStart.month - 1]} $y';
}

List<RatingBarPoint> weeklyStatsToBarPoints(List<WeeklyRatingStats> weeks) {
  return [
    for (final w in weeks)
      RatingBarPoint(
        label: shortWeekLabel(w.weekStartMonday),
        value: w.average,
        ratedCount: w.ratedDaysCount,
      ),
  ];
}

List<RatingBarPoint> monthlyStatsToBarPoints(List<MonthlyRatingStats> months) {
  return [
    for (final m in months)
      RatingBarPoint(
        label: shortMonthLabel(m.monthStart),
        value: m.average,
        ratedCount: m.ratedDaysCount,
      ),
  ];
}
