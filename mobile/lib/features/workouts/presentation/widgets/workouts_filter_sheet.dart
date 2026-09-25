import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/date_range_filter_bar.dart';
import '../../../../shared/widgets/ds/lifey_sheet.dart';
import '../../../../shared/widgets/ds/section_label.dart';
import '../../domain/activity_type.dart';

/// The Sessions filter sheet behind the header's `tune` button: the period and
/// the type — All, Strength, Cardio or one activity — as choice chips
/// (docs/redesign/77-mobile-redesign-plan.md R3.1; the two popup menus of the
/// old header are gone). [kind] is the encoded value `WorkoutsScreen` keeps:
/// `''` all, `'STRENGTH'`, `'CARDIO'` or an activity-type code.
Future<void> showSessionsFilterSheet(
  BuildContext context, {
  required DateRangeFilter range,
  required String kind,
  required ValueChanged<DateRangeFilter> onRange,
  required ValueChanged<String> onKind,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showLifeySheet<void>(
    context: context,
    useRootNavigator: true,
    title: l10n.workoutsFilterTitle,
    showClose: true,
    builder: (_) => _FilterBody(
      sections: [
        _section<DateRangeFilter>(
          label: l10n.workoutsFilterPeriod,
          selected: range,
          options: [for (final r in DateRangeFilter.values) (value: r, label: r.label(l10n))],
          onSelected: onRange,
        ),
        _section<String>(
          label: l10n.workoutsFilterType,
          selected: kind,
          options: [
            (value: '', label: l10n.allFilterLabel),
            (value: 'STRENGTH', label: l10n.activityTypeStrength),
            (value: 'CARDIO', label: l10n.sessionKindCardioLabel),
            for (final type in kActivityTypes) (value: type, label: activityTypeLabel(l10n, type)),
          ],
          onSelected: onKind,
        ),
      ],
    ),
  );
}

/// The Exercises filter sheet: the muscle group ([category] null = all).
Future<void> showExercisesFilterSheet(
  BuildContext context, {
  required String? category,
  required List<({String value, String label})> categories,
  required ValueChanged<String?> onCategory,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showLifeySheet<void>(
    context: context,
    useRootNavigator: true,
    title: l10n.workoutsFilterTitle,
    showClose: true,
    builder: (_) => _FilterBody(
      sections: [
        _section<String>(
          label: l10n.workoutsFilterMuscleGroup,
          selected: category ?? '',
          options: [(value: '', label: l10n.allFilterLabel), ...categories],
          onSelected: (v) => onCategory(v.isEmpty ? null : v),
        ),
      ],
    ),
  );
}

/// One chip group. Non-generic on purpose: the body keeps a list of them, and
/// a `ValueChanged<String>` stored as a `ValueChanged<dynamic>` fails when
/// called — [_section] does the cast once, where the type is known.
class _Section {
  const _Section({required this.label, required this.selected, required this.options, required this.onSelected});

  final String label;
  final Object? selected;
  final List<({Object? value, String label})> options;
  final ValueChanged<Object?> onSelected;
}

_Section _section<T>({
  required String label,
  required T selected,
  required List<({T value, String label})> options,
  required ValueChanged<T> onSelected,
}) =>
    _Section(
      label: label,
      selected: selected,
      options: [for (final o in options) (value: o.value as Object?, label: o.label)],
      onSelected: (v) => onSelected(v as T),
    );

/// Chips apply at once — the sheet stays open so several can be changed —
/// and the sheet keeps its own copy of each selection to redraw the checks.
class _FilterBody extends StatefulWidget {
  const _FilterBody({required this.sections});

  final List<_Section> sections;

  @override
  State<_FilterBody> createState() => _FilterBodyState();
}

class _FilterBodyState extends State<_FilterBody> {
  late final List<Object?> _selected = [for (final s in widget.sections) s.selected];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, section) in widget.sections.indexed) ...[
          if (i > 0) const SizedBox(height: AppSpacing.s16),
          SectionLabel(section.label),
          const SizedBox(height: AppSpacing.s8),
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              for (final option in section.options)
                ChoiceChip(
                  label: Text(option.label),
                  selected: _selected[i] == option.value,
                  onSelected: (_) {
                    setState(() => _selected[i] = option.value);
                    section.onSelected(option.value);
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }
}
