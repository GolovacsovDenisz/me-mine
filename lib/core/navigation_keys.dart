import 'package:flutter/material.dart';

/// Root [NavigatorState] for deep links from local notifications (GoRouter).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);
