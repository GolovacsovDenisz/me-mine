import 'package:flutter_test/flutter_test.dart';

import 'package:me_mine/features/calendar/domain/utils/calendar_entry_utils.dart';
import 'package:me_mine/features/journal/domain/entities/entry.dart';

void main() {
  group('calendarDayHasEntry', () {
    test('returns false for null entry', () {
      expect(calendarDayHasEntry(null), isFalse);
    });

    test('returns true when entry has text', () {
      expect(
        calendarDayHasEntry(
          const Entry(
            id: '2026-06-09',
            dateId: '2026-06-09',
            text: 'Hello',
            rating: 0,
            imageUrls: [],
            localImagePaths: [],
            files: [],
            location: null,
            music: null,
            createdAt: null,
            updatedAt: null,
          ),
        ),
        isTrue,
      );
    });

    test('returns false for empty entry', () {
      expect(
        calendarDayHasEntry(
          const Entry(
            id: '2026-06-09',
            dateId: '2026-06-09',
            text: '',
            rating: 0,
            imageUrls: [],
            localImagePaths: [],
            files: [],
            location: null,
            music: null,
            createdAt: null,
            updatedAt: null,
          ),
        ),
        isFalse,
      );
    });
  });
}
