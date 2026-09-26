import 'package:flutter/material.dart';

import '../../../../../core/theme/app_tokens.dart';
import '../../../../../core/theme/app_type.dart';

/// The client detail's tab row (canvas Lifey 6, client overview): text-only
/// 14/700 labels on a scrolling row, the active one in the primary text
/// colour with a 3 px primary underline as wide as the tab, and a hairline
/// under the whole row.
///
/// Seven tabs never fit a phone as text, so the row scrolls sideways from the
/// start edge and the underline follows the controller — a swipe on the body
/// moves it the same way a tap does. Labels are never shortened: Hungarian
/// "Táplálkozás" and "Ütemezés" scroll into view instead.
class ClientTabBar extends StatelessWidget {
  const ClientTabBar({super.key, required this.controller, required this.labels, this.edge = AppSpacing.screen});

  final TabController controller;
  final List<String> labels;

  /// The screen margin the row's first label lines up with; the wide pane's
  /// content sits further in than a phone's.
  final double edge;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hairline))),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: EdgeInsets.symmetric(horizontal: edge - AppSpacing.s12),
        labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 3),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: p.text,
        unselectedLabelColor: p.text2,
        labelStyle: _style,
        unselectedLabelStyle: _style,
        dividerColor: Colors.transparent,
        // A pressed tab is one surface step lighter elsewhere; a ripple on a
        // row this thin only smears the underline.
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        tabs: [for (final label in labels) Tab(text: label, height: 46)],
      ),
    );
  }

  static const TextStyle _style = TextStyle(
    fontFamily: AppType.fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.1,
  );
}
