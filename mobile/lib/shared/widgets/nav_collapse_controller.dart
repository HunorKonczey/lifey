import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// NavCollapseController
// ---------------------------------------------------------------------------
// Single source of truth for the "are the nav bars collapsed?" state.
// Driven by scroll events from any scrollable in the active tab.
//
// Logic mirrors Lifey Nav Prototype.dc.html (the <script> at the bottom):
//   |delta| < threshold  → ignore (jitter)
//   pixels < nearTopPx   → always expand (near the top of the list)
//   delta > 0            → collapse (user scrolled down)
//   delta < 0            → expand   (user scrolled up)
// ---------------------------------------------------------------------------

class NavCollapseController extends ChangeNotifier {
  bool _collapsed = false;

  bool get collapsed => _collapsed;

  /// Threshold below which a single-frame scroll delta is ignored.
  /// Flutter fires per-frame, so 1px is a safe minimum to drop sub-pixel noise.
  static const double _threshold = 1.0;

  /// Always expand when the scroll offset is below this pixel value.
  static const double _nearTopPx = 20.0;

  /// Feed this into a [NotificationListener<ScrollNotification>] in the shell
  /// or each tab's body. Returns false so notifications keep bubbling.
  bool handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final pixels = notification.metrics.pixels;
      final delta = notification.scrollDelta ?? 0.0;

      if (delta.abs() < _threshold) return false;

      final bool shouldCollapse;
      if (pixels < _nearTopPx) {
        shouldCollapse = false; // near the top — always show the bars
      } else if (delta > 0) {
        shouldCollapse = true; // scrolled down → collapse
      } else {
        shouldCollapse = false; // scrolled up → expand
      }

      if (shouldCollapse != _collapsed) {
        _collapsed = shouldCollapse;
        notifyListeners();
      }
    }

    // ScrollEndNotification: if the user flings and the content bounces back
    // near the top, snap expanded.
    if (notification is ScrollEndNotification) {
      if (notification.metrics.pixels < _nearTopPx && _collapsed) {
        _collapsed = false;
        notifyListeners();
      }
    }

    return false; // don't absorb — let the notification keep bubbling
  }

  /// Force-expand (e.g. when switching tabs the new tab starts at the top).
  void expand() {
    if (_collapsed) {
      _collapsed = false;
      notifyListeners();
    }
  }
}

// ---------------------------------------------------------------------------
// NavCollapseScope — InheritedNotifier so dependent widgets rebuild cheaply
// ---------------------------------------------------------------------------

class NavCollapseScope extends InheritedNotifier<NavCollapseController> {
  const NavCollapseScope({
    super.key,
    required NavCollapseController controller,
    required super.child,
  }) : super(notifier: controller);

  /// The controller itself — use when you need to call [handleScrollNotification]
  /// or [expand].
  static NavCollapseController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<NavCollapseScope>();
    assert(scope != null, 'No NavCollapseScope found in context');
    return scope!.notifier!;
  }

  /// Just the collapsed bool — rebuilds the caller when it changes.
  static bool collapsedOf(BuildContext context) => of(context).collapsed;
}

// ---------------------------------------------------------------------------
// ScrollCollapseListener — thin wrapper a tab body köré
// ---------------------------------------------------------------------------
// Helyezd a tab body legkülső scrollable-je (ListView, CustomScrollView, stb.)
// köré. A NotificationListener elfogja a scroll-értesítéseket és frissíti
// a NavCollapseController-t — nincs szükség ScrollController megosztásra.
//
// Használat:
//   ScrollCollapseListener(
//     child: ListView( ... ),
//   )

class ScrollCollapseListener extends StatelessWidget {
  const ScrollCollapseListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final controller = NavCollapseScope.of(context);
    return NotificationListener<ScrollNotification>(
      onNotification: controller.handleScrollNotification,
      child: child,
    );
  }
}
