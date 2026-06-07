import 'package:flutter/material.dart';

/// Reference: warm “bone” canvas, white cards, soft ink — not harsh #000 / #FFF.
abstract final class AppColors {
  /// Main canvas (light).
  static const Color bone = Color(0xFFF5F3EF);

  /// Cards / sheets on top of bone.
  static const Color surfaceCard = Color(0xFFFAFAF8);

  /// Primary text (soft black).
  static const Color ink = Color(0xFF1A1917);

  static const Color inkMuted = Color(0xFF5E5C58);

  /// Hairlines / dividers.
  static const Color line = Color(0xFFE4E1DB);
  static const Color lineStrong = Color(0xFFCFC9C0);

  /// Primary actions (filled buttons): near-black, not pure black.
  static const Color primary = ink;

  /// Classic destructive — muted brick, not neon.
  static const Color danger = Color(0xFFC44740);

  /// Classic positive — muted forest, not acid green.
  static const Color success = Color(0xFF3D6A48);

  /// Muted gold for ratings (not harsh amber).
  static const Color star = Color(0xFFC4A052);

  // Legacy names used in a few widgets (login, etc.)
  static const Color black = ink;
  static const Color white = surfaceCard;
}
