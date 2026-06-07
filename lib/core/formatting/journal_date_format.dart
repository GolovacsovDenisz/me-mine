import 'dart:ui' as ui;

import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

bool _dateFormattingReady = false;

/// Call once from [main] before any [formatJournalDateId] use.
Future<void> initJournalDateFormatting() async {
  if (_dateFormattingReady) return;
  await initializeDateFormatting('en_GB');
  await initializeDateFormatting('ru');
  _dateFormattingReady = true;
  Intl.defaultLocale = journalDisplayLocale();
}

/// Locale for month names in the UI (`10 May 2026` / `10 мая 2026`).
String journalDisplayLocale() {
  final lang = ui.PlatformDispatcher.instance.locale.languageCode;
  return lang == 'ru' ? 'ru' : 'en_GB';
}

DateTime? _tryParseDateId(String dateId) {
  final p = dateId.split('-');
  if (p.length != 3) return null;
  final y = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  final d = int.tryParse(p[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

String _safeLocale(String? locale) {
  final loc = locale ?? journalDisplayLocale();
  if (loc == 'ru') return 'ru';
  return 'en_GB';
}

/// User-facing calendar dates: `10 May 2026` (storage stays `yyyy-mm-dd`).
String formatJournalDateId(String dateId, {String? locale}) {
  final parsed = _tryParseDateId(dateId);
  if (parsed == null) return dateId;
  return formatJournalDate(parsed, locale: locale);
}

String formatJournalDate(DateTime date, {String? locale}) {
  return DateFormat('d MMM y', _safeLocale(locale)).format(date);
}

String formatJournalDateRange(
  String fromDateId,
  String toDateId, {
  String? locale,
}) {
  final loc = _safeLocale(locale);
  return '${formatJournalDateId(fromDateId, locale: loc)} — '
      '${formatJournalDateId(toDateId, locale: loc)}';
}
