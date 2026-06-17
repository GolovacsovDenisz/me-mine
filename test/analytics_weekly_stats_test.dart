import 'package:flutter_test/flutter_test.dart';
import 'package:me_mine/features/analytics/domain/utils/analytics_weekly_stats.dart';
import 'package:me_mine/features/journal/domain/entities/entry.dart';

Entry _entry(String dateId, int rating) {
  return Entry(
    id: dateId,
    dateId: dateId,
    text: '',
    rating: rating,
    imageUrls: const [],
    localImagePaths: const [],
    files: const [],
    location: null,
    music: null,
    createdAt: null,
    updatedAt: null,
  );
}

void main() {
  group('analytics rating aggregation', () {
    test('computes weekly averages and ignores unrated days', () {
      final weeks = computeWeeklyAverages(
        [
          _entry('2026-06-01', 5),
          _entry('2026-06-08', 4),
          _entry('2026-06-09', 2),
          _entry('2026-06-10', 0),
        ],
        weekCount: 2,
        now: DateTime(2026, 6, 10),
      );

      expect(weeks, hasLength(2));
      expect(weeks[0].weekStartMonday, DateTime(2026, 6, 1));
      expect(weeks[0].average, 5);
      expect(weeks[0].ratedDaysCount, 1);
      expect(weeks[1].weekStartMonday, DateTime(2026, 6, 8));
      expect(weeks[1].average, 3);
      expect(weeks[1].ratedDaysCount, 2);
    });

    test('computes monthly averages for the requested month window', () {
      final months = computeMonthlyAverages(
        [
          _entry('2026-05-03', 5),
          _entry('2026-05-20', 1),
          _entry('2026-06-02', 4),
          _entry('2026-06-05', 0),
        ],
        monthCount: 2,
        now: DateTime(2026, 6, 10),
      );

      expect(months, hasLength(2));
      expect(months[0].monthStart, DateTime(2026, 5, 1));
      expect(months[0].average, 3);
      expect(months[0].ratedDaysCount, 2);
      expect(months[1].monthStart, DateTime(2026, 6, 1));
      expect(months[1].average, 4);
      expect(months[1].ratedDaysCount, 1);
    });

    test('builds daily rating points with zero for missing days', () {
      final points = computeDailyRatings(
        [_entry('2026-06-08', 2), _entry('2026-06-10', 5)],
        dayCount: 3,
        now: DateTime(2026, 6, 10),
      );

      expect(points.map((p) => p.label), ['8/06', '9/06', '10/06']);
      expect(points.map((p) => p.value), [2, 0, 5]);
      expect(points.map((p) => p.ratedCount), [1, 0, 1]);
    });
  });
}
