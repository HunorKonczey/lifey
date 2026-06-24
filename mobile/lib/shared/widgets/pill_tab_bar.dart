import 'package:flutter/material.dart';

/// Pill-shaped segmented tab bar.
///
/// Wraps a [TabBar] in a rounded container so the active tab indicator
/// appears as a filled pill rather than an underline. Drop this in place of
/// any [TabBar] where the mockup calls for the stadium-segment style.
///
/// The [tabs] list is passed straight to [TabBar.tabs] — use [Tab(text: …)]
/// for text-only tabs. Height is fixed at 38 px; side padding is handled
/// internally.
class PillTabBar extends StatelessWidget {
  const PillTabBar({
    super.key,
    required this.controller,
    required this.tabs,
  });

  final TabController controller;
  final List<Widget> tabs;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(99),
        ),
        child: TabBar(
          controller: controller,
          indicator: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(99),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          labelColor: scheme.onPrimary,
          unselectedLabelColor: scheme.onSurfaceVariant,
          labelStyle: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.0,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.0,
          ),
          tabs: tabs,
        ),
      ),
    );
  }
}
