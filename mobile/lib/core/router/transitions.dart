import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

// Page transitions of design system v2 (motion "Oldalváltás", 300 ms):
// shared-axis X for pushes within a tab, fade-through between bottom-nav tabs.
// Built in-house instead of package:animations — only these two are needed
// (docs/redesign/77-mobile-redesign-plan.md D-R0.12, R0.5).

/// Material shared-axis X: the incoming page slides 30 px in from the right
/// while fading in over the last 70 %; the page underneath slides 30 px left
/// while fading out over the first 30 %. Popping plays it in reverse.
///
/// Installed for Android (and desktop) through `pageTransitionsTheme`, so it
/// applies to every `MaterialPage` go_router builds and every
/// `MaterialPageRoute` pushed by hand. iOS keeps the Cupertino transition —
/// replacing it would remove the edge swipe-back gesture.
class SharedAxisXPageTransitionsBuilder extends PageTransitionsBuilder {
  const SharedAxisXPageTransitionsBuilder();

  /// Horizontal travel of both pages.
  static const double offset = 30;

  static const Interval _fadeIn = Interval(0.3, 1, curve: AppMotion.standard);
  static const Interval _fadeOut = Interval(0, 0.3, curve: AppMotion.standard);

  @override
  Duration get transitionDuration => AppMotion.page;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    return _SharedAxisX(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      fill: Theme.of(context).scaffoldBackgroundColor,
      child: child,
    );
  }
}

class _SharedAxisX extends StatelessWidget {
  const _SharedAxisX({
    required this.animation,
    required this.secondaryAnimation,
    required this.fill,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Color fill;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final enter = CurvedAnimation(parent: animation, curve: AppMotion.standard);
    final exit = CurvedAnimation(parent: secondaryAnimation, curve: AppMotion.standard);
    // Order matters: this page's own entrance wraps the fill, so the fill
    // fades in with it; the exit sits inside the fill, so a page being
    // covered fades to the background colour rather than to black.
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: SharedAxisXPageTransitionsBuilder._fadeIn),
      child: AnimatedBuilder(
        animation: enter,
        builder: (context, child) => Transform.translate(
          offset: Offset(SharedAxisXPageTransitionsBuilder.offset * (1 - enter.value), 0),
          child: child,
        ),
        child: ColoredBox(
          color: fill,
          child: FadeTransition(
            opacity: ReverseAnimation(
              CurvedAnimation(parent: secondaryAnimation, curve: SharedAxisXPageTransitionsBuilder._fadeOut),
            ),
            child: AnimatedBuilder(
              animation: exit,
              builder: (context, child) => Transform.translate(
                offset: Offset(-SharedAxisXPageTransitionsBuilder.offset * exit.value, 0),
                child: child,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// The `pageTransitionsTheme` for both app themes.
const PageTransitionsTheme lifeyPageTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: SharedAxisXPageTransitionsBuilder(),
    TargetPlatform.fuchsia: SharedAxisXPageTransitionsBuilder(),
    TargetPlatform.linux: SharedAxisXPageTransitionsBuilder(),
    TargetPlatform.windows: SharedAxisXPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
  },
);

/// Branch container for a `StatefulShellRoute` that fades through when the
/// active tab changes: the old tab fades out over the first 30 %, then the
/// new one fades in while scaling from 0.92 to 1.
///
/// Behaves like go_router's `indexedStack` container otherwise — every
/// branch stays mounted (state and scroll position survive a tab switch),
/// inactive ones are `Offstage` with their tickers off. Each child keeps the
/// same wrapper chain whether or not it is animating, so switching never
/// rebuilds a branch's element subtree.
class FadeThroughBranchContainer extends StatefulWidget {
  const FadeThroughBranchContainer({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  /// Scale the incoming tab starts from.
  static const double startScale = 0.92;

  @override
  State<FadeThroughBranchContainer> createState() => _FadeThroughBranchContainerState();
}

class _FadeThroughBranchContainerState extends State<FadeThroughBranchContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: AppMotion.page, value: 1);
  int? _previousIndex;

  static const Interval _in = Interval(0.3, 1, curve: AppMotion.standard);
  static const Interval _out = Interval(0, 0.3, curve: AppMotion.standard);

  @override
  void didUpdateWidget(FadeThroughBranchContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex == widget.currentIndex) return;
    _previousIndex = oldWidget.currentIndex;
    final duration = AppMotion.of(context, AppMotion.page);
    if (duration == Duration.zero) {
      _controller.value = 1;
      return;
    }
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final animating = _controller.isAnimating;
        final fadeIn = CurvedAnimation(parent: _controller, curve: _in);
        final fadeOut = ReverseAnimation(CurvedAnimation(parent: _controller, curve: _out));
        final scaleIn = Tween<double>(begin: FadeThroughBranchContainer.startScale, end: 1).animate(fadeIn);
        return Stack(
          fit: StackFit.expand,
          children: [
            for (var i = 0; i < widget.children.length; i++)
              _branch(
                index: i,
                active: i == widget.currentIndex,
                leaving: animating && i == _previousIndex,
                fadeIn: fadeIn,
                fadeOut: fadeOut,
                scaleIn: scaleIn,
                animating: animating,
              ),
          ],
        );
      },
    );
  }

  Widget _branch({
    required int index,
    required bool active,
    required bool leaving,
    required Animation<double> fadeIn,
    required Animation<double> fadeOut,
    required Animation<double> scaleIn,
    required bool animating,
  }) {
    final Animation<double> opacity;
    final Animation<double> scale;
    if (active && animating) {
      opacity = fadeIn;
      scale = scaleIn;
    } else if (leaving) {
      opacity = fadeOut;
      scale = kAlwaysCompleteAnimation;
    } else {
      opacity = kAlwaysCompleteAnimation;
      scale = kAlwaysCompleteAnimation;
    }
    return Offstage(
      offstage: !active && !leaving,
      child: TickerMode(
        enabled: active,
        child: IgnorePointer(
          ignoring: !active,
          child: FadeTransition(
            opacity: opacity,
            child: ScaleTransition(scale: scale, child: widget.children[index]),
          ),
        ),
      ),
    );
  }
}
