import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/ds/list_group.dart';

/// The pieces every Settings group is made of (canvas Lifey 5 › 8;
/// docs/redesign/77-mobile-redesign-plan.md R5.7): rows with a neutral icon
/// holder on one grouped card, a value or a control on the right.

/// A settings row: [icon] in a neutral holder, [title], an optional
/// [subtitle] and a [trailing] control or value.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.color,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Tints the icon holder and the title — the destructive "Log out".
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListRow(
      leading: ListIconHolder(icon: icon, color: color ?? p.text, size: 40),
      title: title,
      subtitle: subtitle,
      subtitleMaxLines: 3,
      trailing: trailing,
      onTap: onTap,
    );
  }
}

/// "System ›" / "3 on ›" — a current value with the chevron that says the row
/// opens something.
class SettingsValue extends StatelessWidget {
  const SettingsValue(this.value, {super.key, this.chevron = true});

  final String value;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: p.text2),
          ),
        ),
        if (chevron) Icon(Icons.chevron_right_rounded, size: 22, color: p.text2),
      ],
    );
  }
}

/// A small segmented pill for a two- or three-way setting in a row (Units,
/// Theme): the chosen option in the primary colour on a control track. Scales
/// down rather than wrapping when a long Hungarian label meets a narrow phone.
class InlinePillSegment<T> extends StatelessWidget {
  const InlinePillSegment({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s4),
          decoration: BoxDecoration(
            color: p.control,
            borderRadius: AppRadius.pill,
            border: Border.all(color: context.elevation.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (value, label) in options)
                Semantics(
                  button: true,
                  selected: value == selected,
                  inMutuallyExclusiveGroup: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(value),
                    child: AnimatedContainer(
                      duration: AppMotion.of(context, AppMotion.page),
                      curve: AppMotion.standard,
                      constraints: const BoxConstraints(minHeight: 32),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
                      decoration: BoxDecoration(
                        color: value == selected ? scheme.primary : Colors.transparent,
                        borderRadius: AppRadius.pill,
                      ),
                      child: Text(
                        label,
                        style: t.labelLarge!.copyWith(
                          fontWeight: value == selected ? FontWeight.w700 : FontWeight.w600,
                          color: value == selected ? scheme.onPrimary : p.text2,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The row switch: the primary track with an on-primary thumb when on, a quiet
/// outlined track with a grey thumb when off (canvas: Health Connect "Off").
class SettingsSwitch extends StatelessWidget {
  const SettingsSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    return Switch(
      value: value,
      onChanged: onChanged,
      thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? scheme.onPrimary : p.text2),
      trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? scheme.primary : p.control),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? Colors.transparent : context.elevation.border,
      ),
    );
  }
}
