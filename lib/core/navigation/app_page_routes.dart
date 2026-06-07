import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../motion/app_motion.dart';

/// Slide + fade; keeps Cupertino interactive back / edge swipe where supported.
Route<T> appDetailRoute<T extends Object?>(Widget page) {
  return _SmoothCupertinoPageRoute<T>(builder: (_) => page);
}

class _SmoothCupertinoPageRoute<T> extends CupertinoPageRoute<T> {
  _SmoothCupertinoPageRoute({required super.builder});

  @override
  Duration get transitionDuration => AppMotion.medium;

  @override
  Duration get reverseTransitionDuration => AppMotion.fast;
}

/// Full-screen step (e.g. PIN setup): gentle fade instead of a hard cut.
Route<T> appModalFadeRoute<T extends Object?>(Widget page) {
  return PageRouteBuilder<T>(
    opaque: true,
    barrierColor: Colors.black26,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(opacity: curved, child: child);
    },
  );
}
