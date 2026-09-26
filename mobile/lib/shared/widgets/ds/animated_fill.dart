import 'package:flutter/widgets.dart';

import '../../../core/theme/app_tokens.dart';

/// Drives ring and bar fills (design system v2 motion "Gyűrű és sáv":
/// 900 ms, enter curve, 60 ms stagger; docs/redesign/77-mobile-redesign-plan.md
/// R0.9).
///
/// Unlike a number count-up, a fill **does** animate in on first appearance
/// — from 0, after [delay] (use `AppMotion.staggered(i)` for the i-th macro).
/// After that, a change animates only the difference, from whatever is on
/// screen. Equal values on rebuild don't restart anything; under reduced
/// motion every value lands at once.
///
/// Works on a list so a multi-segment bar animates its segments together.
class AnimatedFill extends StatefulWidget {
  const AnimatedFill({
    super.key,
    required this.values,
    required this.builder,
    this.delay = Duration.zero,
    this.animateIn = true,
  });

  final List<double> values;
  final Widget Function(BuildContext context, List<double> values) builder;

  /// Entrance delay (stagger); ignored for later changes.
  final Duration delay;

  /// false = the first build shows [values] directly.
  final bool animateIn;

  @override
  State<AnimatedFill> createState() => _AnimatedFillState();
}

class _AnimatedFillState extends State<AnimatedFill> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late List<double> _from;
  late List<double> _to;
  Curve _curve = AppMotion.enter;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _to = List.of(widget.values);
    _from = widget.animateIn ? List.filled(_to.length, 0) : List.of(_to);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The entrance starts here rather than in initState: reduced motion is
    // read from the MediaQuery, which initState can't depend on.
    if (!_started) {
      _started = true;
      _run(entrance: true);
    }
  }

  @override
  void didUpdateWidget(AnimatedFill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_listEquals(widget.values, _to)) return;
    _from = _current();
    _to = List.of(widget.values);
    _run(entrance: false);
  }

  void _run({required bool entrance}) {
    final fill = AppMotion.of(context, AppMotion.fill);
    if (fill == Duration.zero || _listEquals(_from, _to)) {
      _from = List.of(_to);
      _controller.value = 1;
      return;
    }
    final delay = entrance ? widget.delay : Duration.zero;
    final total = fill + delay;
    final start = delay.inMicroseconds / total.inMicroseconds;
    _curve = Interval(start, 1, curve: AppMotion.enter);
    _controller
      ..duration = total
      ..forward(from: 0);
  }

  List<double> _current() {
    final t = _curve.transform(_controller.value);
    return [
      for (var i = 0; i < _to.length; i++)
        _lerp(i < _from.length ? _from[i] : 0, _to[i], t),
    ];
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  static bool _listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => widget.builder(context, _current()),
      );
}
