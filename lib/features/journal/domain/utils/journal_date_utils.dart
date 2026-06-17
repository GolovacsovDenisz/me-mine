abstract final class JournalDateUtils {
  /// Firestore document id for a calendar day, formatted as `yyyy-mm-dd`.
  static String dateId(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Parses a calendar id `yyyy-mm-dd`. Returns `null` if invalid.
  static DateTime? tryParseDateId(String dateId) {
    final p = dateId.split('-');
    if (p.length != 3) return null;
    try {
      final y = int.parse(p[0]);
      final m = int.parse(p[1]);
      final d = int.parse(p[2]);
      return DateTime(y, m, d);
    } on FormatException {
      return null;
    }
  }
}
