import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/navigation_keys.dart';
import '../../../journal/domain/entities/entry.dart';

const _journalNotificationId = 92001;
const _androidChannelId = 'journal_reminder';
const _payloadOpenHome = 'journal_home';

final FlutterLocalNotificationsPlugin _plugin =
    FlutterLocalNotificationsPlugin();

bool _initialized = false;

Future<void> initJournalLocalNotifications() async {
  if (_initialized) return;
  if (kIsWeb) return;

  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const darwin = DarwinInitializationSettings();
  const initSettings = InitializationSettings(
    android: android,
    iOS: darwin,
    macOS: darwin,
  );

  await _plugin.initialize(
    settings: initSettings,
    onDidReceiveNotificationResponse: _onNotificationTap,
  );

  if (defaultTargetPlatform == TargetPlatform.android) {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _androidChannelId,
            'Journal reminders',
            description: 'Nudges you to save today’s journal entry.',
            importance: Importance.defaultImportance,
          ),
        );
  }

  _initialized = true;
}

void _onNotificationTap(NotificationResponse response) {
  if (response.payload != _payloadOpenHome) return;
  final ctx = rootNavigatorKey.currentContext;
  if (ctx == null) return;
  GoRouter.of(ctx).go('/');
}

/// Android 13+ runtime permission; iOS/macOS dialog on first enable.
Future<bool> requestJournalNotificationPermissions() async {
  if (kIsWeb) return false;
  if (defaultTargetPlatform == TargetPlatform.android) {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? false;
  }
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;
  }
  if (defaultTargetPlatform == TargetPlatform.macOS) {
    final mac = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    return await mac?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;
  }
  return false;
}

/// Same bar as “Save” on Home: text + rating 1–5.
bool todayEntryLooksSaved(Entry? e) {
  if (e == null) return false;
  if (e.text.trim().isEmpty) return false;
  if (e.rating < 1 || e.rating > 5) return false;
  return true;
}

tz.TZDateTime _nextScheduledFire({
  required DateTime now,
  required int hour,
  required int minute,
  required bool todayEntryComplete,
}) {
  final loc = tz.local;
  if (todayEntryComplete) {
    final tomorrow = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    return tz.TZDateTime(
      loc,
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      hour,
      minute,
    );
  }
  var candidate = tz.TZDateTime(
    loc,
    now.year,
    now.month,
    now.day,
    hour,
    minute,
  );
  if (!now.isBefore(candidate)) {
    candidate = candidate.add(const Duration(days: 1));
  }
  return candidate;
}

Future<void> cancelJournalReminder() async {
  if (!_initialized || kIsWeb) return;
  await _plugin.cancel(id: _journalNotificationId);
}

/// Schedules **one** next local notification. Re-run after save, resume, prefs,
/// or midnight logic via bootstrap — OS cannot re-check Firestore by itself.
Future<void> syncJournalReminderSchedule({
  required bool enabled,
  required int hour,
  required int minute,
  required Entry? todayEntry,
}) async {
  if (!_initialized || kIsWeb) return;

  await _plugin.cancel(id: _journalNotificationId);
  if (!enabled) return;

  final now = DateTime.now();
  final complete = todayEntryLooksSaved(todayEntry);
  final next = _nextScheduledFire(
    now: now,
    hour: hour,
    minute: minute,
    todayEntryComplete: complete,
  );

  const title = 'Me Mine';
  const body = 'Save today’s journal when you can — tap to open the app.';

  final details = NotificationDetails(
    android: AndroidNotificationDetails(
      _androidChannelId,
      'Journal reminders',
      channelDescription: 'Daily reminder for your journal.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: const DarwinNotificationDetails(),
    macOS: const DarwinNotificationDetails(),
  );

  await _plugin.zonedSchedule(
    id: _journalNotificationId,
    scheduledDate: next,
    notificationDetails: details,
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    title: title,
    body: body,
    payload: _payloadOpenHome,
  );
}
