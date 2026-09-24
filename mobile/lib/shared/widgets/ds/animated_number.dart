import 'package:flutter/widgets.dart';

import '../../../core/theme/app_tokens.dart';

/// A number that rolls from its previous value to the new one (design system
/// v2 motion "Szám-count-up", 600 ms; docs/redesign/77-mobile-redesign-plan.md
/// R0.5).
///
/// - The first build shows [value] directly — nothing counts up from 0 when a
///   screen opens.
/// - A rebuild with an equal value does nothing, so a provider refresh
///   doesn't make every number on screen re-animate (plan §9 risk 7).
/// - A change mid-animation continues from the number currently shown, not
///   from the old target.
/// - Under reduced motion the new value shows on the next frame.
///
/// [builder] receives the in-between value; round it for display there (e.g.
/// `LifeyFormat.kcal`). Pair with tabular figures (MetricValue, AppType.number)
/// so the width doesn't jitter while digits change. Screen readers only get
/// the final value: the animating child is excluded from semantics and
/// [semanticsLabel] is announced instead.
class AnimatedNumber extends StatefulWidget {
  const AnimatedNumber({
    super.key,
    required this.value,
    required this.builder,
    this.semanticsLabel,
    this.duration = AppMotion.countUp,
    this.curve = AppMotion.standard,
  });

  final num value;
  final Widget Function(BuildContext context, double value) builder;

  /// Read by screen readers instead of the animated text. When null the
  /// builder's own semantics (for the final value) are used.
  final String? semanticsLabel;

  final Duration duration;
  final Curve curve;

  @override
  State<AnimatedNumber> createState() => _AnimatedNumberState();
}

class _AnimatedNumberState extends State<AnimatedNumber> with SingleTickerProviderStateMixin {
  // Created eagerly: a lazy controller that is first touched in dispose()
  // would look up TickerMode on an already deactivated element.
  late final AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _animation = AlwaysStoppedAnimation(widget.value.toDouble());
  }

  @override
  void didUpdateWidget(AnimatedNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == oldWidget.value) return;
    final from = _animation.value;
    final to = widget.value.toDouble();
    final duration = AppMotion.of(context, widget.duration);
    if (duration == Duration.zero) {
      _controller.stop();
      _animation = AlwaysStoppedAnimation(to);
      return;
    }
    _animation = Tween<double>(begin: from, end: to)
        .chain(CurveTween(curve: widget.curve))
        .animate(_controller);
    _controller
      ..duration = duration
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = AnimatedBuilder(
      animation: _animation,
      builder: (context, _) => widget.builder(context, _animation.value),
    );
    if (widget.semanticsLabel == null) return child;
    return Semantics(
      label: widget.semanticsLabel,
      child: ExcludeSemantics(child: child),
    );
  }
}
