import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// Shows a design-system bottom sheet (canvas "BOTTOM SHEET", Lifey 2
/// "Add food", Lifey 4 "Log weight"; docs/redesign/77-mobile-redesign-plan.md
/// R0.12): surface-2, radius 30 on top, a 36 × 4 handle, a 20/800 [title]
/// with either a [trailing] value (e.g. "0.99 / 2.60 L" in the water colour)
/// or a close button, then [child]. Slides up in 350 ms on the enter curve;
/// the backdrop dims to 40 %; dragging it down closes it. Keyboard and safe
/// area are handled, and the content scrolls if it's taller than the screen.
Future<T?> showLifeySheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
  Widget? trailing,
  bool showClose = false,
  bool isDismissible = true,
}) {
  final duration = AppMotion.of(context, AppMotion.sheet);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: isDismissible,
    sheetAnimationStyle: AnimationStyle(
      duration: duration,
      reverseDuration: duration,
      curve: AppMotion.enter,
      reverseCurve: AppMotion.exit,
    ),
    builder: (context) => LifeySheet(
      title: title,
      trailing: trailing,
      showClose: showClose,
      child: builder(context),
    ),
  );
}

/// The body of a design-system sheet — use through [showLifeySheet], or
/// directly inside an existing `showModalBottomSheet` builder while a
/// feature migrates.
class LifeySheet extends StatelessWidget {
  const LifeySheet({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.showClose = false,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final bool showClose;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 10, AppSpacing.screen, AppSpacing.s20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.text3.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              Row(children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title, style: t.titleLarge!.copyWith(fontWeight: FontWeight.w800, height: 1.2, color: p.text)),
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: AppSpacing.s12), trailing!],
                if (showClose)
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                    icon: Icon(Icons.close_rounded, size: 24, color: p.text2),
                  ),
              ]),
              const SizedBox(height: AppSpacing.s16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
