import 'package:flutter/material.dart';

import '../../../../core/format/lifey_format.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/lifey_card.dart';
import '../../../../shared/widgets/ds/lifey_sheet.dart';
import '../../../../shared/widgets/ds/metric_value.dart';
import '../../domain/user_settings.dart';

/// The six daily goals as small tiles — a metric dot, the name, the value
/// (canvas: "DAILY GOALS"). Three to a row; every tile opens its own editor.
/// A goal that is not set reads "—", except steps, which shows the default
/// (10 000) that the rest of the app uses.
class DailyGoalTiles extends StatelessWidget {
  const DailyGoalTiles({
    super.key,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.waterLiters,
    required this.steps,
    required this.onEdit,
  });

  final int? calories;
  final int? protein;
  final int? carbs;
  final int? fat;
  final double? waterLiters;
  final int? steps;

  /// Called with which goal was tapped.
  final ValueChanged<GoalKind> onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final mc = context.metricColors;

    String whole(int? v) => v == null ? '—' : f.integer(v);
    final tiles = [
      (GoalKind.calories, l10n.caloriesLabel, mc.calories, whole(calories), null as String?),
      (GoalKind.protein, l10n.proteinLabel, mc.protein, whole(protein), protein == null ? null : 'g'),
      (GoalKind.carbs, l10n.carbsLabel, mc.carbs, whole(carbs), carbs == null ? null : 'g'),
      (GoalKind.fat, l10n.fatLabel, mc.fat, whole(fat), fat == null ? null : 'g'),
      (
        GoalKind.water,
        l10n.waterLabel,
        mc.water,
        waterLiters == null ? '—' : f.decimal(waterLiters!, waterLiters! == waterLiters!.roundToDouble() ? 0 : 1),
        waterLiters == null ? null : 'L'
      ),
      // No goal set = the default, shown instead of "—" (canvas Lifey 5).
      (GoalKind.steps, l10n.stepsLabel, mc.steps, f.integer(steps ?? UserSettings.defaultDailyStepGoal), null),
    ];

    Widget row(int from) => Row(
          children: [
            for (var i = from; i < from + 3; i++) ...[
              if (i > from) const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: _GoalTile(
                  label: tiles[i].$2,
                  color: tiles[i].$3,
                  value: tiles[i].$4,
                  unit: tiles[i].$5,
                  onTap: () => onEdit(tiles[i].$1),
                ),
              ),
            ],
          ],
        );

    return Column(
      children: [
        IntrinsicHeight(child: row(0)),
        const SizedBox(height: AppSpacing.s8),
        IntrinsicHeight(child: row(3)),
      ],
    );
  }
}

enum GoalKind { calories, protein, carbs, fat, water, steps }

class _GoalTile extends StatelessWidget {
  const _GoalTile({required this.label, required this.color, required this.value, required this.unit, required this.onTap});

  final String label;
  final Color color;
  final String value;
  final String? unit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return LifeyCard.nested(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s12),
      semanticsLabel: '$label $value${unit == null ? '' : ' $unit'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelMedium!.copyWith(color: p.text2)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: MetricValue(value: value, unit: unit, size: 22),
          ),
        ],
      ),
    );
  }
}

/// Opens the editor of one goal: a number field and Save. Blank clears the
/// goal.
Future<void> showGoalEditSheet(
  BuildContext context, {
  required String label,
  required String suffix,
  required String initialText,
  required bool decimal,
  required void Function(String text) onSave,
}) =>
    showLifeySheet<void>(
      context: context,
      title: label,
      showClose: true,
      builder: (_) => _GoalEditBody(suffix: suffix, initialText: initialText, decimal: decimal, onSave: onSave),
    );

class _GoalEditBody extends StatefulWidget {
  const _GoalEditBody({required this.suffix, required this.initialText, required this.decimal, required this.onSave});

  final String suffix;
  final String initialText;
  final bool decimal;
  final void Function(String text) onSave;

  @override
  State<_GoalEditBody> createState() => _GoalEditBodyState();
}

class _GoalEditBodyState extends State<_GoalEditBody> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Capture validation strings at build time — avoids context lookups
    // inside the validator closure (which could run after disposal).
    final intError = l10n.enterNonNegativeWholeNumber;
    final decimalError = l10n.enterNonNegativeNumber;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.s8),
          TextFormField(
            controller: _controller,
            autofocus: true,
            keyboardType: widget.decimal ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.number,
            decoration: InputDecoration(suffixText: widget.suffix, hintText: l10n.leaveBlankForNoGoal),
            validator: (value) {
              final text = (value ?? '').replaceAll(',', '.').trim();
              if (text.isEmpty) return null;
              final parsed = widget.decimal ? double.tryParse(text) : int.tryParse(text);
              if (parsed == null || parsed < 0) return widget.decimal ? decimalError : intError;
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.s24),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  widget.onSave(_controller.text.replaceAll(',', '.').trim());
                  Navigator.of(context).pop();
                }
              },
              child: Text(l10n.saveButton),
            ),
          ),
        ],
      ),
    );
  }
}
