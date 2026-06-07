import 'dart:async';

import 'package:flutter/material.dart';

/// Reveals [text] line by line (live-typing feel after AI finishes on the server).
class TypewriterText extends StatefulWidget {
  const TypewriterText({
    super.key,
    required this.text,
    this.style,
    this.lineDelay = const Duration(milliseconds: 120),
    this.animate = true,
    this.showCursorWhileTyping = true,
    this.onFinished,
  });

  final String text;
  final TextStyle? style;
  final Duration lineDelay;
  final bool animate;
  final bool showCursorWhileTyping;
  final VoidCallback? onFinished;

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  String _visible = '';
  Timer? _timer;
  List<String> _lines = const [];
  int _lineIndex = 0;
  bool _done = true;

  @override
  void initState() {
    super.initState();
    _applyText(reset: true);
  }

  @override
  void didUpdateWidget(covariant TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.animate != widget.animate) {
      _applyText(reset: true);
    }
  }

  void _applyText({required bool reset}) {
    _timer?.cancel();
    final full = widget.text;
    if (full.isEmpty) {
      setState(() {
        _visible = '';
        _done = true;
      });
      widget.onFinished?.call();
      return;
    }

    if (!widget.animate) {
      setState(() {
        _visible = full;
        _done = true;
      });
      widget.onFinished?.call();
      return;
    }

    _lines = full.split('\n');
    _lineIndex = 0;
    _visible = '';
    _done = false;
    setState(() {});
    _scheduleNextLine();
  }

  void _scheduleNextLine() {
    _timer?.cancel();
    if (_lineIndex >= _lines.length) {
      if (!_done) {
        setState(() => _done = true);
        widget.onFinished?.call();
      }
      return;
    }

    _timer = Timer(widget.lineDelay, () {
      if (!mounted) return;
      setState(() {
        if (_lineIndex > 0) _visible += '\n';
        _visible += _lines[_lineIndex];
        _lineIndex++;
      });
      _scheduleNextLine();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? Theme.of(context).textTheme.bodyLarge;
    final showCursor = widget.showCursorWhileTyping && !_done && widget.animate;

    return SelectableText(showCursor ? '$_visible▌' : _visible, style: style);
  }
}

/// Shown while the Cloud Function is still generating.
class AiWritingIndicator extends StatefulWidget {
  const AiWritingIndicator({super.key});

  @override
  State<AiWritingIndicator> createState() => _AiWritingIndicatorState();
}

class _AiWritingIndicatorState extends State<AiWritingIndicator> {
  int _dots = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (!mounted) return;
      setState(() => _dots = (_dots + 1) % 4);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tail = '.' * _dots;
    return Row(
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Writing summary$tail',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
