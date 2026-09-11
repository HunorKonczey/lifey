import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/network/error_message.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../application/client_detail_providers.dart';
import '../../data/client_detail_repository.dart';
import '../../domain/client_data.dart';

/// The outcome of saving goals, as the tab needs to report it.
enum GoalsSaveOutcome {
  /// Something actually changed, so the backend sent the client a push
  /// (docs/32: on change only).
  changed,

  /// The trainer saved the same numbers back. Nothing was notified, and
  /// saying otherwise would be a small lie about someone else's phone.
  unchanged,
}

/// Sets a client's daily macro targets (T7 — the write half of the nutrition
/// tab's read).
///
/// Every field may be left blank, and blank means *no goal* rather than zero:
/// a zero calorie target would read as 100% over on the first bite.
class NutritionGoalsSheet extends ConsumerStatefulWidget {
  const NutritionGoalsSheet({
    super.key,
    required this.clientId,
    required this.goals,
  });

  final int clientId;
  final ClientNutritionGoals goals;

  static Future<GoalsSaveOutcome?> show(
    BuildContext context, {
    required int clientId,
    required ClientNutritionGoals goals,
  }) {
    return showModalBottomSheet<GoalsSaveOutcome>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => NutritionGoalsSheet(clientId: clientId, goals: goals),
    );
  }

  @override
  ConsumerState<NutritionGoalsSheet> createState() => _NutritionGoalsSheetState();
}

class _NutritionGoalsSheetState extends ConsumerState<NutritionGoalsSheet> {
  late final _calories = _controllerFor(widget.goals.dailyCalorieGoal);
  late final _protein = _controllerFor(widget.goals.dailyProteinGoal);
  late final _carbs = _controllerFor(widget.goals.dailyCarbsGoal);
  late final _fat = _controllerFor(widget.goals.dailyFatGoal);

  bool _saving = false;
  String? _error;

  TextEditingController _controllerFor(double? value) =>
      TextEditingController(text: value == null ? '' : value.round().toString());

  @override
  void dispose() {
    _calories.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    super.dispose();
  }

  double? _valueOf(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final wanted = ClientNutritionGoals(
      dailyCalorieGoal: _valueOf(_calories),
      dailyProteinGoal: _valueOf(_protein),
      dailyCarbsGoal: _valueOf(_carbs),
      dailyFatGoal: _valueOf(_fat),
    );

    try {
      final saved = await ref
          .read(clientDetailRepositoryProvider)
          .updateNutritionGoals(widget.clientId, wanted);
      ref.invalidate(clientNutritionGoalsProvider(widget.clientId));
      if (!mounted) return;
      Navigator.of(context).pop(
        _sameAs(widget.goals, saved)
            ? GoalsSaveOutcome.unchanged
            : GoalsSaveOutcome.changed,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = friendlyError(error);
        });
      }
    }
  }

  static bool _sameAs(ClientNutritionGoals a, ClientNutritionGoals b) =>
      a.dailyCalorieGoal == b.dailyCalorieGoal &&
      a.dailyProteinGoal == b.dailyProteinGoal &&
      a.dailyCarbsGoal == b.dailyCarbsGoal &&
      a.dailyFatGoal == b.dailyFatGoal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.trainerNutritionGoalsTitle,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.trainerNutritionGoalsSubtitle,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          _GoalField(
            controller: _calories,
            label: l10n.caloriesLabel,
            suffix: 'kcal',
            enabled: !_saving,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _GoalField(
                  controller: _protein,
                  label: l10n.proteinLabel,
                  suffix: 'g',
                  enabled: !_saving,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _GoalField(
                  controller: _carbs,
                  label: l10n.carbsLabel,
                  suffix: 'g',
                  enabled: !_saving,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _GoalField(
                  controller: _fat,
                  label: l10n.fatLabel,
                  suffix: 'g',
                  enabled: !_saving,
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            l10n.trainerNutritionGoalsBlankHint,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Spacer(),
              if (_saving)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(l10n.saveButton),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalField extends StatelessWidget {
  const _GoalField({
    required this.controller,
    required this.label,
    required this.suffix,
    required this.enabled,
  });

  final TextEditingController controller;
  final String label;
  final String suffix;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      // The API takes whole numbers; keeping the keyboard to digits stops a
      // decimal point becoming a 400.
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
