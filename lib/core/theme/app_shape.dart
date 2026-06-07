import 'package:flutter/material.dart';

/// Shared corner radii (premium / soft, not sharp).
abstract final class AppShape {
  static const double xs = 10;
  static const double sm = 14;
  static const double md = 18;
  static const double lg = 22;
  static const double xl = 28;

  static BorderRadius get radiusMd => BorderRadius.circular(md);
  static BorderRadius get radiusLg => BorderRadius.circular(lg);
}
