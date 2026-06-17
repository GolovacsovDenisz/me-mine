import 'package:flutter_test/flutter_test.dart';
import 'package:me_mine/features/journal/domain/utils/journal_date_utils.dart';

void main() {
  group('JournalDateUtils', () {
    test('formats DateTime values as yyyy-mm-dd ids', () {
      expect(JournalDateUtils.dateId(DateTime(2026, 6, 9)), '2026-06-09');
      expect(JournalDateUtils.dateId(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('parses valid yyyy-mm-dd ids', () {
      expect(
        JournalDateUtils.tryParseDateId('2026-06-09'),
        DateTime(2026, 6, 9),
      );
    });

    test('returns null for malformed date ids', () {
      expect(JournalDateUtils.tryParseDateId('2026/06/09'), isNull);
      expect(JournalDateUtils.tryParseDateId('2026-06'), isNull);
      expect(JournalDateUtils.tryParseDateId('not-a-date'), isNull);
    });
  });
}
