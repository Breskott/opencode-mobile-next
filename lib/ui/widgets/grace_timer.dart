import 'dart:async';

import 'package:flutter/widgets.dart';

/// How long a server may take to answer before the app says it isn't:
/// a normal start or reconnect on a phone finishes well inside it, so
/// nothing is said during an ordinary start (work-tab cleanup spec, 8 s).
const notAnsweringGrace = Duration(seconds: 8);

/// Builds with `overdue == true` once [waiting] has stayed true for
/// [grace]. Any stretch where [waiting] is false resets the clock, and so
/// does a change of [restartKey] (for example a new connect attempt).
class GraceTimer extends StatefulWidget {
  const GraceTimer({
    super.key,
    required this.waiting,
    required this.builder,
    this.grace = notAnsweringGrace,
    this.restartKey,
  });

  final bool waiting;
  final Duration grace;
  final Object? restartKey;
  final Widget Function(BuildContext context, bool overdue) builder;

  @override
  State<GraceTimer> createState() => _GraceTimerState();
}

class _GraceTimerState extends State<GraceTimer> {
  Timer? _timer;
  bool _overdue = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(GraceTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.restartKey != widget.restartKey ||
        oldWidget.grace != widget.grace) {
      _reset();
    }
    _sync();
  }

  void _reset() {
    _timer?.cancel();
    _timer = null;
    _overdue = false;
  }

  void _sync() {
    if (!widget.waiting) {
      _reset();
      return;
    }
    if (_overdue || _timer != null) return;
    _timer = Timer(widget.grace, () {
      _timer = null;
      if (mounted) setState(() => _overdue = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, widget.waiting && _overdue);
}
