import 'package:flutter/widgets.dart';

import '../../../core/theme/app_tokens.dart';

/// Tap feedback for cards and tiles (design system v2 motion "Érintés":
/// the card scales to 0.98 in 100 ms, and there is **no ripple on big
/// cards**; docs/redesign/77-mobile-redesign-plan.md R0.5).
///
/// Buttons keep Material's own feedback (a one-step lighter tone, set in the
/// button themes); this is for surfaces that are tappable as a whole.
/// Disabled (no [onTap] and no [onLongPress]) it renders [child] untouched.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.semanticsLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Optional label for the tappable surface as a whole.
  final String? semanticsLabel;

  /// Scale while pressed.
  static const double pressedScale = 0.98;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _set(bool pressed) {
    if (_pressed != pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return widget.child;
    return Semantics(
      button: true,
      label: widget.semanticsLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        // Only with a long-press handler — otherwise screen readers would be
        // offered a long-press action that does nothing.
        onLongPressEnd: widget.onLongPress == null ? null : (_) => _set(false),
        child: AnimatedScale(
          scale: _pressed ? Pressable.pressedScale : 1,
          duration: AppMotion.of(context, AppMotion.tap),
          curve: AppMotion.standard,
          child: widget.child,
        ),
      ),
    );
  }
}
