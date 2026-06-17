import 'package:flutter/material.dart';

import '../../../../core/motion/app_motion.dart';

/// Wraps [child] with a staggered rise-from-bottom entrance (calendar cells).
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.slideDistance = 14,
  });

  final int index;
  final Widget child;
  final double slideDistance;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late Animation<double> _t;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _buildTween();
    _c.forward();
  }

  void _buildTween() {
    final row = widget.index ~/ 7;
    final col = widget.index % 7;
    final order = row * 7 + col;
    final start = (order * 0.028).clamp(0.0, 0.72);
    final end = (start + 0.38).clamp(0.0, 1.0);
    _t = CurvedAnimation(
      parent: _c,
      curve: Interval(start, end, curve: AppMotion.enter),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) {
        final v = _t.value;
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, widget.slideDistance * (1 - v)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
