import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class JournalReminderPrefs {
  const JournalReminderPrefs({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  final bool enabled;
  final int hour;
  final int minute;
}

final journalReminderPrefsProvider =
    NotifierProvider<JournalReminderPrefsNotifier, JournalReminderPrefs>(
      JournalReminderPrefsNotifier.new,
    );

class JournalReminderPrefsNotifier extends Notifier<JournalReminderPrefs> {
  static const _kEnabled = 'journal_reminder_enabled';
  static const _kHour = 'journal_reminder_hour';
  static const _kMinute = 'journal_reminder_minute';

  @override
  JournalReminderPrefs build() {
    Future<void>.delayed(Duration.zero, _load);
    return const JournalReminderPrefs(enabled: false, hour: 20, minute: 0);
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    state = JournalReminderPrefs(
      enabled: p.getBool(_kEnabled) ?? false,
      hour: p.getInt(_kHour) ?? 20,
      minute: p.getInt(_kMinute) ?? 0,
    );
  }

  Future<void> setEnabled(bool value) async {
    state = JournalReminderPrefs(
      enabled: value,
      hour: state.hour,
      minute: state.minute,
    );
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kEnabled, value);
  }

  Future<void> setTime({required int hour, required int minute}) async {
    state = JournalReminderPrefs(
      enabled: state.enabled,
      hour: hour,
      minute: minute,
    );
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kHour, hour);
    await p.setInt(_kMinute, minute);
  }
}
