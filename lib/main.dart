import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'app.dart';
import 'core/formatting/journal_date_format.dart';
import 'features/notifications/journal_reminder_bootstrap.dart';
import 'features/notifications/journal_reminder_service.dart';
import 'firebase_options.dart';

Future<void> _configureLocalTimeZone() async {
  tz_data.initializeTimeZones();
  final tzInfo = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _configureLocalTimeZone();
  await initJournalDateFormatting();
  await initJournalLocalNotifications();

  runApp(const ProviderScope(child: JournalReminderBootstrap(child: App())));
}
