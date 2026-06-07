import 'package:flutter/material.dart';

import '../core/motion/app_motion.dart';
import '../core/theme/app_shape.dart';

/// Fades + slight rise on first paint (lists, empty states, content blocks).
class FadeInAppear extends StatefulWidget {
  const FadeInAppear({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offsetY = 10,
    this.duration = AppMotion.medium,
  });

  final Widget child;
  final Duration delay;
  final double offsetY;
  final Duration duration;

  @override
  State<FadeInAppear> createState() => _FadeInAppearState();
}

class _FadeInAppearState extends State<FadeInAppear>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
    _fade = CurvedAnimation(parent: _c, curve: AppMotion.enter);
    _slide = Tween<Offset>(
      begin: Offset(0, widget.offsetY / 100),
      end: Offset.zero,
    ).animate(_fade);
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Soft pulsing placeholder block.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    required this.height,
    this.width,
    this.borderRadius,
  });

  final double height;
  final double? width;
  final BorderRadius? borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = 0.45 + _c.value * 0.25;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? AppShape.radiusMd,
            color: Color.lerp(
              scheme.surfaceContainerHighest,
              scheme.surfaceContainerHigh,
              t,
            ),
          ),
        );
      },
    );
  }
}

/// Home / generic form loading placeholder.
class AppLoadingPlaceholder extends StatelessWidget {
  const AppLoadingPlaceholder.home({super.key}) : _variant = _Variant.home;

  const AppLoadingPlaceholder.calendar({super.key})
    : _variant = _Variant.calendar;

  const AppLoadingPlaceholder.analytics({super.key})
    : _variant = _Variant.analytics;

  final _Variant _variant;

  @override
  Widget build(BuildContext context) {
    return FadeInAppear(
      child: switch (_variant) {
        _Variant.home => const _HomeSkeleton(),
        _Variant.calendar => const _CalendarSkeleton(),
        _Variant.analytics => const _AnalyticsSkeleton(),
      },
    );
  }
}

enum _Variant { home, calendar, analytics }

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SkeletonBox(height: 28, width: 220),
          const SizedBox(height: 8),
          const SkeletonBox(height: 16, width: 140),
          const SizedBox(height: 16),
          const SkeletonBox(height: 88),
          const SizedBox(height: 16),
          const SkeletonBox(height: 160),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: SkeletonBox(height: 64)),
              const SizedBox(width: 12),
              Expanded(child: SkeletonBox(height: 64)),
              const SizedBox(width: 12),
              Expanded(child: SkeletonBox(height: 64)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              5,
              (_) => const SkeletonBox(
                height: 36,
                width: 36,
                borderRadius: BorderRadius.all(Radius.circular(18)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarSkeleton extends StatelessWidget {
  const _CalendarSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SkeletonBox(height: 24, width: 160),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: 35,
            itemBuilder: (_, _) => const SkeletonBox(height: 48),
          ),
        ),
      ],
    );
  }
}

class _AnalyticsSkeleton extends StatelessWidget {
  const _AnalyticsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SkeletonBox(height: 36),
        const SizedBox(height: 12),
        const SkeletonBox(height: 200),
        const SizedBox(height: 16),
        const SkeletonBox(height: 72),
        const SizedBox(height: 8),
        const SkeletonBox(height: 72),
      ],
    );
  }
}

/// Cross-fade between tab roots while keeping all tabs alive (scroll/state).
class CrossfadeIndexedStack extends StatelessWidget {
  const CrossfadeIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = AppMotion.fast,
  });

  final int index;
  final List<Widget> children;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < children.length; i++)
          IgnorePointer(
            ignoring: i != index,
            child: AnimatedOpacity(
              opacity: i == index ? 1 : 0,
              duration: duration,
              curve: AppMotion.enter,
              child: children[i],
            ),
          ),
      ],
    );
  }
}
