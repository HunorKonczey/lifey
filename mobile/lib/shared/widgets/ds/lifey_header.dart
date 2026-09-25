import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_tokens.dart';

// The v2 header system (docs/redesign/77-mobile-redesign-plan.md R0.10;
// canvas Design System › "FEJLÉC · scrim + nagy cím", Lifey 1 top/scrolled,
// Lifey 2 "Edit meal", Lifey 5 chat):
//
// - LifeyHeader — main tabs: a large 30/800 title (with an optional date
//   overline) that shrinks to a 20/800 row as the page scrolls; pinned, so
//   the scrim under the status bar is always there once content moves.
// - LifeySubpageHeader — every pushed screen: round back button + 20/800
//   title (+ subtitle / avatar) + actions, as a drop-in `Scaffold.appBar`.
// - Both sit on the scrim: bg at 88–90 % with a backdrop blur, and a
//   hairline once content scrolls underneath — nothing ever shows through
//   the status bar unblurred ("A görgetett tartalom átcsúszik a státuszsor
//   alá" is fixed here).

/// Height of the collapsed header row / the subpage row.
const double _rowHeight = 52;

/// The scrim layer behind a header: bg at 90 % + blur, and a hairline at
/// the bottom when [showHairline].
class _ScrimBackground extends StatelessWidget {
  const _ScrimBackground({required this.opacity, required this.showHairline});

  final double opacity;
  final bool showHairline;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (opacity <= 0) return const SizedBox.expand();
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
            sigmaX: AppElevation.floatBlur, sigmaY: AppElevation.floatBlur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: p.bg.withValues(alpha: 0.9 * opacity),
            border: Border(
              bottom: BorderSide(
                  color: showHairline ? p.hairline : Colors.transparent),
            ),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Status-bar icon colours that match the theme (light icons on dark).
SystemUiOverlayStyle _overlayStyle(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

// ---------------------------------------------------------------------------
// Round header button
// ---------------------------------------------------------------------------

/// The 44 px round header button on surface-2 (chat, search, back), with an
/// optional unread dot in the calorie colour. A 48 dp touch target.
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.showDot = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;

  /// Unread / attention dot (canvas: 9 px, calorie orange, 2 px ring).
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final button = IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 22),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(44),
        minimumSize: const Size.square(44),
        tapTargetSize: MaterialTapTargetSize.padded,
        backgroundColor: p.nested,
        foregroundColor: p.text,
        shape: const CircleBorder(),
      ),
    );
    if (!showDot) return button;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        Positioned(
          // 48 dp layout box around a 44 px circle → +2 px; canvas dot at 9/9.
          top: 11,
          right: 11,
          child: IgnorePointer(
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: context.metricColors.calories,
                shape: BoxShape.circle,
                border: Border.all(color: p.nested, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Large-title header (main tabs)
// ---------------------------------------------------------------------------

/// The large-title header of a main tab, as a pinned sliver for a
/// `CustomScrollView`. Expanded: optional [overline] (13/600, secondary — the
/// date on Today) over a 30/800 [title] that may take two lines; [actions]
/// (usually [HeaderIconButton]s and a MonogramAvatar) sit bottom-right.
/// Scrolling shrinks it to a 52 px row with a 20/800 title while the scrim
/// fades in behind it. Extents are measured from the text, so a long
/// Hungarian title or 130 % text never overflows.
class LifeyHeader extends StatelessWidget {
  const LifeyHeader({
    super.key,
    required this.title,
    this.overline,
    this.collapsedTitle,
    this.actions = const [],
  });

  final String title;
  final String? overline;

  /// What the 20 px row says once the page has scrolled — canvas Lifey 1
  /// scrolled: the "Good morning, Anna" of the expanded header becomes
  /// "Today". Null keeps [title] (shrunk). The two cross-fade around the
  /// half-way point; screen readers only ever get [title].
  final String? collapsedTitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final mq = MediaQuery.of(context);
    final scaler = mq.textScaler;
    // 48 per action + 8 gaps, reserved at the right of the title.
    final actionsWidth = actions.isEmpty
        ? 0.0
        : actions.length * 48.0 + (actions.length - 1) * 8 + 12;
    final titleWidth = (mq.size.width - 2 * AppSpacing.screen - actionsWidth)
        .clamp(80.0, double.infinity);

    final titleStyle = t.headlineMedium!;
    final overlineStyle =
        t.bodySmall!.copyWith(fontSize: 13, fontWeight: FontWeight.w600);
    double measure(String text, TextStyle style, int maxLines) => (TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: Directionality.of(context),
          textScaler: scaler,
          maxLines: maxLines,
        )..layout(maxWidth: titleWidth))
            .height;

    final titleHeight = measure(title, titleStyle, 2);
    final overlineHeight =
        overline == null ? 0.0 : measure(overline!, overlineStyle, 1) + 2;
    final top = mq.padding.top;
    final minExtent = top + _rowHeight;
    final expandedBody =
        AppSpacing.s8 + overlineHeight + titleHeight + AppSpacing.s4;
    final maxExtent =
        top + (expandedBody > _rowHeight + 12 ? expandedBody : _rowHeight + 12);

    return SliverPersistentHeader(
      pinned: true,
      delegate: _LargeTitleDelegate(
        title: title,
        overline: overline,
        collapsedTitle: collapsedTitle,
        actions: actions,
        minExtentValue: minExtent,
        maxExtentValue: maxExtent,
        topPadding: top,
        titleStyle: titleStyle,
        overlineStyle: overlineStyle,
        actionsWidth: actionsWidth,
      ),
    );
  }
}

class _LargeTitleDelegate extends SliverPersistentHeaderDelegate {
  _LargeTitleDelegate({
    required this.title,
    required this.overline,
    required this.collapsedTitle,
    required this.actions,
    required this.minExtentValue,
    required this.maxExtentValue,
    required this.topPadding,
    required this.titleStyle,
    required this.overlineStyle,
    required this.actionsWidth,
  });

  final String title;
  final String? overline;
  final String? collapsedTitle;
  final List<Widget> actions;
  final double minExtentValue;
  final double maxExtentValue;
  final double topPadding;
  final TextStyle titleStyle;
  final TextStyle overlineStyle;
  final double actionsWidth;

  @override
  double get minExtent => minExtentValue;

  @override
  double get maxExtent => maxExtentValue;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final p = context.palette;
    final range = maxExtent - minExtent;
    final t = range <= 0 ? 1.0 : (shrinkOffset / range).clamp(0.0, 1.0);
    final collapsed = t >= 1;
    final fontSize = lerpDouble(titleStyle.fontSize, 20, t)!;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlayStyle(context),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _ScrimBackground(
              opacity: t, showHairline: collapsed || overlapsContent),
          Positioned(
            left: AppSpacing.screen,
            right: AppSpacing.screen + actionsWidth,
            // Bottom-anchored: as the header shrinks the title rides up, and
            // in the collapsed 52 px row it ends vertically centred.
            bottom: lerpDouble(AppSpacing.s4, 14, t),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (overline != null)
                  ClipRect(
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      heightFactor: 1 - t,
                      child: Opacity(
                        opacity: (1 - 2 * t).clamp(0.0, 1.0),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(overline!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: overlineStyle.copyWith(color: p.text2)),
                        ),
                      ),
                    ),
                  ),
                // Only the title is the heading; the date overline stays
                // plain text, so it isn't read as part of the header.
                Semantics(
                  header: true,
                  child: Opacity(
                    opacity: collapsedTitle == null
                        ? 1
                        : (1 - 2 * t).clamp(0.0, 1.0),
                    child: Text(
                      title,
                      maxLines: t < 0.5 ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle.copyWith(
                        fontSize: fontSize,
                        height: lerpDouble(titleStyle.height, 1.2, t),
                        letterSpacing: lerpDouble(
                            -0.02 * titleStyle.fontSize!, -0.01 * 20, t),
                        color: p.text,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (collapsedTitle != null)
            Positioned(
              left: AppSpacing.screen,
              right: AppSpacing.screen + actionsWidth,
              bottom: 14,
              child: ExcludeSemantics(
                child: Opacity(
                  opacity: (2 * t - 1).clamp(0.0, 1.0),
                  child: Text(
                    collapsedTitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle.copyWith(
                      fontSize: 20,
                      height: 1.2,
                      letterSpacing: -0.01 * 20,
                      color: p.text,
                    ),
                  ),
                ),
              ),
            ),
          if (actions.isNotEmpty)
            Positioned(
              right: AppSpacing.screen -
                  2, // the 48 dp touch box around a 44 px circle
              bottom: 0,
              height: _rowHeight,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.s8),
                  actions[i],
                ],
              ]),
            ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_LargeTitleDelegate old) =>
      old.title != title ||
      old.overline != overline ||
      old.collapsedTitle != collapsedTitle ||
      old.actions != actions ||
      old.minExtentValue != minExtentValue ||
      old.maxExtentValue != maxExtentValue ||
      old.titleStyle != titleStyle;
}

// ---------------------------------------------------------------------------
// Subpage header
// ---------------------------------------------------------------------------

/// The header of every pushed screen — a drop-in `Scaffold.appBar`
/// (replaces the plain Material `AppBar`s and, later, `AdaptiveAppBar`).
///
/// Round back button (auto when the route can pop), optional [leading]
/// (e.g. the chat partner's avatar), a 20/800 [title] — 18/800 with a
/// [subtitle] under it — and [actions] (HeaderIconButtons, or a primary
/// "Save" `FilledButton`). Always on the scrim; the hairline appears once
/// content scrolls underneath (use `extendBodyBehindAppBar: true` to let it
/// scroll under the blur).
class LifeySubpageHeader extends StatefulWidget implements PreferredSizeWidget {
  const LifeySubpageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleColor,
    this.leading,
    this.actions = const [],
    this.onBack,
    this.showBack = true,
  });

  final String title;
  final String? subtitle;

  /// e.g. protein green for "Your trainer · online".
  final Color? subtitleColor;

  final Widget? leading;
  final List<Widget> actions;

  /// Defaults to `Navigator.maybePop`.
  final VoidCallback? onBack;
  final bool showBack;

  @override
  Size get preferredSize => const Size.fromHeight(_rowHeight + AppSpacing.s8);

  @override
  State<LifeySubpageHeader> createState() => _LifeySubpageHeaderState();
}

class _LifeySubpageHeaderState extends State<LifeySubpageHeader> {
  ScrollNotificationObserverState? _observer;
  bool _scrolledUnder = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _observer?.removeListener(_onScroll);
    // The same hook Material's AppBar uses for "scrolled under".
    _observer = ScrollNotificationObserver.maybeOf(context);
    _observer?.addListener(_onScroll);
  }

  void _onScroll(ScrollNotification n) {
    if (n is! ScrollUpdateNotification ||
        n.depth != 0 ||
        n.metrics.axis != Axis.vertical) {
      return;
    }
    final under = n.metrics.extentBefore > 0;
    if (under != _scrolledUnder) setState(() => _scrolledUnder = under);
  }

  @override
  void dispose() {
    _observer?.removeListener(_onScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final canPop = widget.showBack &&
        (widget.onBack != null || (ModalRoute.of(context)?.canPop ?? false));
    final hasSubtitle = widget.subtitle != null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlayStyle(context),
      child: Stack(
        children: [
          Positioned.fill(
              child:
                  _ScrimBackground(opacity: 1, showHairline: _scrolledUnder)),
          SafeArea(
            bottom: false,
            child: SizedBox(
              height: widget.preferredSize.height,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screen - 2,
                    AppSpacing.s4, AppSpacing.screen - 2, AppSpacing.s4),
                child: Row(children: [
                  if (canPop) ...[
                    HeaderIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip:
                          MaterialLocalizations.of(context).backButtonTooltip,
                      onPressed: widget.onBack ??
                          () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                  ] else
                    const SizedBox(width: 2),
                  if (widget.leading != null) ...[
                    widget.leading!,
                    const SizedBox(width: AppSpacing.s12)
                  ],
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.titleLarge!.copyWith(
                              fontSize: hasSubtitle ? 18 : 20,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                              color: p.text,
                            ),
                          ),
                          if (hasSubtitle)
                            Text(
                              widget.subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.bodySmall!.copyWith(
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                                color: widget.subtitleColor ?? p.text2,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  for (final a in widget.actions) ...[
                    const SizedBox(width: AppSpacing.s8),
                    a
                  ],
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pinned pieces under / instead of the large title (tabbed main screens)
// ---------------------------------------------------------------------------

/// A fixed-height pinned sliver — the tab bar under a [LifeyHeader] in a
/// `NestedScrollView`, which stays put while the title above it collapses.
class LifeyPinnedSliver extends StatelessWidget {
  const LifeyPinnedSliver({super.key, required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) => SliverPersistentHeader(
        pinned: true,
        delegate: _FixedExtentDelegate(extent: height, child: child),
      );
}

class _FixedExtentDelegate extends SliverPersistentHeaderDelegate {
  _FixedExtentDelegate({required this.extent, required this.child});

  final double extent;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  // On the same scrim as the header above it: the tab bar of a
  // NestedScrollView stays put while the list under it scrolls, and that
  // list scrolls *beneath* it, so it needs the blurred backing too.
  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Stack(
        fit: StackFit.expand,
        children: [
          _ScrimBackground(opacity: 1, showHairline: overlapsContent),
          child,
        ],
      );

  @override
  bool shouldRebuild(_FixedExtentDelegate old) =>
      old.extent != extent || old.child != child;
}

/// The header row while a search is open: in place of [LifeyHeader], a
/// search field on the scrim with a round close button. Pinned, like the
/// large-title header, and the same height as its collapsed row so opening
/// and closing a search doesn't move the tab bar under it.
class LifeySearchHeader extends StatelessWidget {
  const LifeySearchHeader({
    super.key,
    required this.controller,
    required this.hint,
    required this.closeTooltip,
    required this.onChanged,
    required this.onClose,
  });

  final TextEditingController controller;
  final String hint;
  final String closeTooltip;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SearchHeaderDelegate(
        extent: top + _rowHeight,
        field: _SearchField(
            controller: controller, hint: hint, onChanged: onChanged),
        closeButton: HeaderIconButton(
          icon: Icons.close_rounded,
          tooltip: closeTooltip,
          onPressed: onClose,
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField(
      {required this.controller, required this.hint, required this.onChanged});

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return SizedBox(
      height: 44,
      child: TextField(
        controller: controller,
        autofocus: true,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: t.bodyLarge!.copyWith(color: p.text),
        cursorColor: p.text,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: t.bodyLarge!.copyWith(color: p.text2),
          prefixIcon: Icon(Icons.search_rounded, size: 22, color: p.text2),
          filled: true,
          fillColor: p.nested,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: const OutlineInputBorder(
              borderRadius: AppRadius.pill, borderSide: BorderSide.none),
          enabledBorder: const OutlineInputBorder(
              borderRadius: AppRadius.pill, borderSide: BorderSide.none),
          focusedBorder: const OutlineInputBorder(
              borderRadius: AppRadius.pill, borderSide: BorderSide.none),
        ),
      ),
    );
  }
}

class _SearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  _SearchHeaderDelegate(
      {required this.extent, required this.field, required this.closeButton});

  final double extent;
  final Widget field;
  final Widget closeButton;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlayStyle(context),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _ScrimBackground(opacity: 1, showHairline: overlapsContent),
          Positioned(
            left: AppSpacing.screen,
            right: AppSpacing.screen - 2,
            bottom: 0,
            height: _rowHeight,
            child: Row(children: [
              Expanded(child: field),
              const SizedBox(width: AppSpacing.s8),
              closeButton,
            ]),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_SearchHeaderDelegate old) =>
      old.extent != extent || old.field != field || old.closeButton != closeButton;
}

// ---------------------------------------------------------------------------
// Status-bar scrim
// ---------------------------------------------------------------------------

/// A blurred bg-at-88 % strip over the status bar, for screens whose content
/// scrolls to the very top without a pinned header (e.g. a live screen with
/// its own layout). Put it last in a `Stack` over the scroll view.
class StatusBarScrim extends StatelessWidget {
  const StatusBarScrim({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    if (top == 0) return const SizedBox.shrink();
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: top,
      child: IgnorePointer(
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: _overlayStyle(context),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                  sigmaX: AppElevation.scrimBlur,
                  sigmaY: AppElevation.scrimBlur),
              child: ColoredBox(color: context.palette.scrim),
            ),
          ),
        ),
      ),
    );
  }
}
