import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/analytics_screen.dart';
import '../calendar/calendar_screen.dart';
import '../home/home_screen.dart';
import '../security/passcode_prefs.dart';
import '../security/passcode_unlock_screen.dart';
import '../../shared/app_motion_widgets.dart';
import '../settings/settings_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  int _index = 0;

  static const _tabs = [
    _Tab(title: 'Home', icon: Icons.edit_note),
    _Tab(title: 'Calendar', icon: Icons.calendar_month),
    _Tab(title: 'Analytics', icon: Icons.insights),
    _Tab(title: 'Settings', icon: Icons.settings),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      final prefs = ref.read(passcodePrefsProvider);
      if (prefs.shouldLockShell) {
        ref.read(passcodeSessionUnlockedProvider.notifier).lock();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tab = _tabs[_index];
    final pass = ref.watch(passcodePrefsProvider);
    final unlocked = ref.watch(passcodeSessionUnlockedProvider);
    final locked = pass.shouldLockShell && !unlocked;

    final body = CrossfadeIndexedStack(
      index: _index,
      children: [
        HomeScreen(onEntrySaved: () => setState(() => _index = 1)),
        const CalendarScreen(),
        const AnalyticsScreen(),
        const SettingsScreen(),
      ],
    );

    return Scaffold(
      appBar: locked ? null : AppBar(title: Text(tab.title)),
      body: SafeArea(
        left: true,
        top: false,
        right: true,
        bottom: false,
        minimum: EdgeInsets.zero,
        child: locked
            ? PasscodeUnlockScreen(
                onUnlocked: () {
                  ref.read(passcodeSessionUnlockedProvider.notifier).unlock();
                },
              )
            : body,
      ),
      bottomNavigationBar: locked
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.edit_note),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.calendar_month),
                  label: 'Calendar',
                ),
                NavigationDestination(
                  icon: Icon(Icons.insights),
                  label: 'Analytics',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
    );
  }
}

class _Tab {
  const _Tab({required this.title, required this.icon});
  final String title;
  final IconData icon;
}
