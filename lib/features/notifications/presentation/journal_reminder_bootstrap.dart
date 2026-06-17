import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../journal/domain/entities/entry.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../journal/domain/utils/journal_date_utils.dart';
import '../../journal/presentation/providers/entries_providers.dart';
import '../data/datasources/journal_reminder_prefs.dart';
import '../data/services/journal_reminder_service.dart';

/// Keeps the next journal reminder aligned with prefs, auth, and today’s entry.
class JournalReminderBootstrap extends ConsumerStatefulWidget {
  const JournalReminderBootstrap({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<JournalReminderBootstrap> createState() =>
      _JournalReminderBootstrapState();
}

class _JournalReminderBootstrapState
    extends ConsumerState<JournalReminderBootstrap>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sync();
    }
  }

  void _sync() {
    final user = ref.read(authStateProvider).value;
    if (user == null) {
      cancelJournalReminder();
      return;
    }

    final prefs = ref.read(journalReminderPrefsProvider);
    final todayId = JournalDateUtils.dateId(DateTime.now());
    final entryAsync = ref.read(entryByDateIdProvider(todayId));
    final Entry? entry = switch (entryAsync) {
      AsyncData(:final value) => value,
      _ => null,
    };

    syncJournalReminderSchedule(
      enabled: prefs.enabled,
      hour: prefs.hour,
      minute: prefs.minute,
      todayEntry: entry,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<dynamic>>(authStateProvider, (previous, next) {
      _sync();
    });
    ref.listen<JournalReminderPrefs>(journalReminderPrefsProvider, (
      previous,
      next,
    ) {
      _sync();
    });

    final todayId = JournalDateUtils.dateId(DateTime.now());
    ref.listen<AsyncValue<dynamic>>(entryByDateIdProvider(todayId), (
      previous,
      next,
    ) {
      _sync();
    });

    return widget.child;
  }
}
