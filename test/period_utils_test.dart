import 'package:flutter_test/flutter_test.dart';
import 'package:me_mine/core/formatting/journal_date_format.dart';
import 'package:me_mine/features/analytics/domain/utils/period_utils.dart';

void main() {
  setUpAll(() async {
    await initJournalDateFormatting();
  });

  group('period ranges', () {
    test('builds the current Monday-Sunday week range', () {
      final range = weekRangeFromOffset(
        weeksAgo: 0,
        now: DateTime(2026, 6, 10),
      );

      expect(range.id, 'week_2026-06-08');
      expect(range.fromDateId, '2026-06-08');
      expect(range.toDateId, '2026-06-14');
      expect(range.from, DateTime(2026, 6, 8));
      expect(range.to, DateTime(2026, 6, 14));
    });

    test('builds previous week ranges from a stable offset', () {
      final range = weekRangeFromOffset(
        weeksAgo: 1,
        now: DateTime(2026, 6, 10),
      );

      expect(range.id, 'week_2026-06-01');
      expect(range.fromDateId, '2026-06-01');
      expect(range.toDateId, '2026-06-07');
    });

    test('builds full calendar month ranges', () {
      final range = monthRangeFromOffset(
        monthsAgo: 0,
        now: DateTime(2026, 6, 10),
      );

      expect(range.id, 'month_2026-06');
      expect(range.fromDateId, '2026-06-01');
      expect(range.toDateId, '2026-06-30');
      expect(range.from, DateTime(2026, 6, 1));
      expect(range.to, DateTime(2026, 6, 30));
    });
  });
}
