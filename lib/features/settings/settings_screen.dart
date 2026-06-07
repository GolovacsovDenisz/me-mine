import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/navigation/app_page_routes.dart';
import '../auth/auth_providers.dart';
import '../notifications/journal_reminder_prefs.dart';
import '../notifications/journal_reminder_service.dart';
import '../security/passcode_prefs.dart';
import '../security/passcode_settings_screen.dart';
import '../security/passcode_storage.dart';
import '../../shared/app_dialogs.dart';
import 'account_dialogs.dart';
import 'theme_mode_provider.dart';
import 'ai_prompt_settings_screen.dart';

final packageInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return PackageInfo.fromPlatform();
});

/// Phase 6 — Settings: theme, reminders, AI prompt, passcode, account, sign-out.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeNotifierProvider);
    final infoAsync = ref.watch(packageInfoProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(
              value: ThemeMode.system,
              label: Text('System'),
              icon: Icon(Icons.brightness_auto, size: 18),
            ),
            ButtonSegment(
              value: ThemeMode.light,
              label: Text('Light'),
              icon: Icon(Icons.light_mode, size: 18),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              label: Text('Dark'),
              icon: Icon(Icons.dark_mode, size: 18),
            ),
          ],
          selected: {themeMode},
          onSelectionChanged: (next) {
            ref
                .read(themeModeNotifierProvider.notifier)
                .setThemeMode(next.first);
          },
        ),
        const SizedBox(height: 24),
        Text('About', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        infoAsync.when(
          data: (info) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: const Text('App version'),
            subtitle: Text('${info.version} (${info.buildNumber})'),
          ),
          loading: () => const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.info_outline),
            title: Text('App version'),
            subtitle: Text('Loading…'),
          ),
          error: (e, _) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: const Text('App version'),
            subtitle: Text('Error: $e'),
          ),
        ),
        const SizedBox(height: 16),
        Text('Reminders', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Builder(
          builder: (context) {
            final reminder = ref.watch(journalReminderPrefsProvider);
            final timeLabel = MaterialLocalizations.of(context).formatTimeOfDay(
              TimeOfDay(hour: reminder.hour, minute: reminder.minute),
              alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(
                context,
              ),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.notifications_outlined),
                  title: const Text('Daily journal reminder'),
                  subtitle: const Text(
                    'One notification per day at your chosen time, only while '
                    'today’s entry is not saved (text + rating). Reschedules when '
                    'you save or open the app.',
                  ),
                  value: reminder.enabled,
                  onChanged: (on) async {
                    if (on) {
                      final ok = await requestJournalNotificationPermissions();
                      if (!context.mounted) return;
                      if (!ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Notification permission is required for reminders.',
                            ),
                          ),
                        );
                        return;
                      }
                    }
                    await ref
                        .read(journalReminderPrefsProvider.notifier)
                        .setEnabled(on);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const SizedBox(width: 40),
                  title: const Text('Reminder time'),
                  subtitle: Text(
                    reminder.enabled
                        ? timeLabel
                        : 'Turn on reminders to pick a time',
                  ),
                  trailing: const Icon(Icons.schedule),
                  enabled: reminder.enabled,
                  onTap: reminder.enabled
                      ? () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: reminder.hour,
                              minute: reminder.minute,
                            ),
                          );
                          if (picked == null || !context.mounted) return;
                          await ref
                              .read(journalReminderPrefsProvider.notifier)
                              .setTime(
                                hour: picked.hour,
                                minute: picked.minute,
                              );
                        }
                      : null,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Text('AI', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.psychology_outlined),
          title: const Text('Instructions for AI'),
          subtitle: const Text('Your own prompt text for analyses (optional).'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(
              context,
            ).push<void>(appDetailRoute(const AiPromptSettingsScreen()));
          },
        ),
        const SizedBox(height: 8),
        Text('Account', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.email_outlined),
          title: const Text('Change email'),
          subtitle: const Text('Sends a confirmation link to the new address.'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () =>
              showChangeEmailDialog(context, ref.read(firebaseAuthProvider)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.password_outlined),
          title: const Text('Change password'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () =>
              showChangePasswordDialog(context, ref.read(firebaseAuthProvider)),
        ),
        const SizedBox(height: 8),
        Text('Security', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.lock_outline),
          title: const Text('App passcode'),
          subtitle: const Text(
            '4-digit PIN after leaving the app. Off by default.',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(
              context,
            ).push<void>(appDetailRoute(const PasscodeSettingsScreen()));
          },
        ),
        const Divider(height: 32),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            Icons.logout,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(
            'Sign out',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          onTap: () async {
            final ok = await showAppConfirmDialog(
              context: context,
              title: 'Sign out?',
              contentText:
                  'You will need to sign in again to view or edit your journal.',
              confirmLabel: 'Sign out',
              isDestructive: true,
            );
            if (ok == true && context.mounted) {
              await clearPasscodeHash();
              await ref.read(passcodePrefsProvider.notifier).clearAll();
              ref.read(passcodeSessionUnlockedProvider.notifier).unlock();
              await ref.read(firebaseAuthProvider).signOut();
            }
          },
        ),
      ],
    );
  }
}
