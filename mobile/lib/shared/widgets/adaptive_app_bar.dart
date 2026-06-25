import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import 'nav_collapse_controller.dart';

// ---------------------------------------------------------------------------
// AdaptiveAppBarAction
// ---------------------------------------------------------------------------

class AdaptiveAppBarAction {
  const AdaptiveAppBarAction({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
}

// ---------------------------------------------------------------------------
// AdaptiveAppBar
// ---------------------------------------------------------------------------
// Floating, scroll-reactive top bar — mirrors the bottom nav collapse logic.
//
// Expanded (not collapsed): height 58, radius 24, title 19/800 + optional
//   subtitle 13/600, action buttons 40×40 / radius 13.
// Collapsed: height 44, radius 18, title 15/800 (no subtitle),
//   action buttons 32×32 / radius 11.
//
// Frosted-glass background via BackdropFilter(blur 12).
// AnimatedContainer drives height + radius + shadow; AnimatedDefaultTextStyle
// drives the title size; subtitle fades out with AnimatedOpacity.
//
// This widget renders its own box — positioning (top margin, side insets) is
// the responsibility of the parent (handled in step 07, MainShell / each screen).
// ---------------------------------------------------------------------------

class AdaptiveAppBar extends StatelessWidget {
  const AdaptiveAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.actions = const [],
    this.trailing,
  });

  /// Main title — shown in both states, animates size.
  final String title;

  /// Optional second line shown only when expanded (dashboard "Good morning").
  final String? subtitle;

  /// If non-null, a back-arrow button is rendered as the leading widget.
  final VoidCallback? onBack;

  /// Right-side icon actions. Same icons in both states, size animates.
  final List<AdaptiveAppBarAction> actions;

  /// Optional widget placed after the icon actions (e.g. a "Save" text button).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final collapsed = NavCollapseScope.collapsedOf(context);
    final scheme = Theme.of(context).colorScheme;

    // Semi-transparent frosted surface — use surfaceContainer (~#22241B dark,
    // #ECEBDE light) at high opacity to match the mockup rgba values.
    final bgColor = scheme.surfaceContainer.withValues(alpha: collapsed ? 0.94 : 0.92);

    return AnimatedContainer(
      duration: AppDuration.collapse,
      curve: AppCurve.collapse,
      clipBehavior: Clip.antiAlias,
      height: collapsed ? 44.0 : 58.0,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(
          collapsed ? AppRadius.input : AppRadius.lg,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: collapsed ? 0.32 : 0.30),
            blurRadius: collapsed ? 18 : 22,
            offset: Offset(0, collapsed ? 6 : 8),
          ),
        ],
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AnimatedPadding(
          duration: AppDuration.collapse,
          curve: AppCurve.collapse,
          padding: EdgeInsets.symmetric(
            horizontal: collapsed ? 8.0 : 12.0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Leading: back button ──────────────────────────────────
              if (onBack != null) ...[
                _AppBarButton(
                  icon: Icons.arrow_back,
                  onPressed: onBack!,
                  collapsed: collapsed,
                  scheme: scheme,
                ),
                SizedBox(width: collapsed ? 6 : 10),
              ],

              // ── Title + optional subtitle ─────────────────────────────
              Expanded(
                child: _TitleBlock(
                  title: title,
                  subtitle: subtitle,
                  collapsed: collapsed,
                  scheme: scheme,
                ),
              ),

              // ── Actions ───────────────────────────────────────────────
              for (final a in actions) ...[
                const SizedBox(width: 4),
                _AppBarButton(
                  icon: a.icon,
                  onPressed: a.onPressed,
                  tooltip: a.tooltip,
                  collapsed: collapsed,
                  scheme: scheme,
                ),
              ],
              if (trailing != null) ...[
                const SizedBox(width: 4),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Title block
// ---------------------------------------------------------------------------

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({
    required this.title,
    required this.subtitle,
    required this.collapsed,
    required this.scheme,
  });

  final String title;
  final String? subtitle;
  final bool collapsed;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subtitle — only in expanded state
        if (subtitle != null)
          AnimatedOpacity(
            opacity: collapsed ? 0.0 : 1.0,
            duration: AppDuration.base,
            curve: Curves.easeOut,
            child: AnimatedSize(
              duration: AppDuration.collapse,
              curve: AppCurve.collapse,
              alignment: Alignment.topLeft,
              child: collapsed
                  ? const SizedBox.shrink()
                  : Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                        height: 1.2,
                      ),
                    ),
            ),
          ),

        // Title
        AnimatedDefaultTextStyle(
          duration: AppDuration.collapse,
          curve: AppCurve.collapse,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: collapsed ? 15.0 : 19.0,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
            letterSpacing: -0.3,
          ),
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Icon action button
// ---------------------------------------------------------------------------

class _AppBarButton extends StatelessWidget {
  const _AppBarButton({
    required this.icon,
    required this.onPressed,
    required this.collapsed,
    required this.scheme,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool collapsed;
  final ColorScheme scheme;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    // Expanded: 40×40 radius 13 | Collapsed: 32×32 radius 11
    final size = collapsed ? 32.0 : 40.0;
    final radius = collapsed ? 11.0 : 13.0;
    final iconSize = collapsed ? 18.0 : 21.0;

    Widget btn = GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppDuration.collapse,
        curve: AppCurve.collapse,
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: AppDuration.fast,
            child: Icon(
              icon,
              key: ValueKey(iconSize),
              size: iconSize,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      btn = Tooltip(message: tooltip!, child: btn);
    }

    return btn;
  }
}
