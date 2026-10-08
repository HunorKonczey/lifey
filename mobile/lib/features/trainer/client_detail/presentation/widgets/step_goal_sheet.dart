import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/network/error_message.dart';
import '../../../../../core/theme/app_tokens.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/widgets/ds/lifey_sheet.dart';
import '../../../clients/application/trainer_clients_controller.dart';
import '../../data/client_detail_repository.dart';
import 'nutrition_goals_sheet.dart' show GoalsSaveOutcome;

/// Sets a client's daily step goal (LIF-105), the write half of the steps tab.
///
/// Blank means *no goal*, not zero: the backend refuses zero, and the field says so before it gets that far.
class StepGoalSheet extends ConsumerStatefulWidget {
  const StepGoalSheet({super.key, required this.clientId, required this.goal});

  final int clientId;
  final int? goal;

  static Future<GoalsSaveOutcome?> show(BuildContext context, {required int clientId, required int? goal}) {
    return showLifeySheet<GoalsSaveOutcome>(
      context: context,
      title: AppLocalizations.of(context)!.trainerStepGoalTitle,
      useRootNavigator: true,
      builder: (_) => StepGoalSheet(clientId: clientId, goal: goal),
    );
  }

  @override
  ConsumerState<StepGoalSheet> createState() => _StepGoalSheetState();
}

class _StepGoalSheetState extends ConsumerState<StepGoalSheet> {
  late final _controller = TextEditingController(text: widget.goal?.toString() ?? '');

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Null for an empty field, the number otherwise; `0` is parsed too, so [_save] can refuse it by name.
  int? get _value {
    final text = _controller.text.trim();
    return text.isEmpty ? null : int.tryParse(text);
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context)!;
    final wanted = _value;
    if (wanted != null && wanted <= 0) {
      setState(() => _error = l10n.trainerStepGoalInvalid);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final saved = await ref.read(clientDetailRepositoryProvider).updateStepGoal(widget.clientId, wanted);
      // The goal rides in the client summary, so the steps tab reads the new one from the refreshed list.
      await ref.read(trainerClientsControllerProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).pop(saved == widget.goal ? GoalsSaveOutcome.unchanged : GoalsSaveOutcome.changed);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = friendlyError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final p = context.palette;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.trainerStepGoalSubtitle, style: theme.textTheme.bodySmall?.copyWith(color: p.text2)),
        const SizedBox(height: 14),
        TextField(
          key: const ValueKey('step-goal-field'),
          controller: _controller,
          enabled: !_saving,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: l10n.trainerStepGoalTitle, suffixText: l10n.trainerStepGoalUnit),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 8),
        Text(l10n.trainerStepGoalBlankHint, style: theme.textTheme.labelSmall?.copyWith(color: p.text2)),
        const SizedBox(height: 12),
        Row(
          children: [
            const Spacer(),
            if (_saving)
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            FilledButton(onPressed: _saving ? null : _save, child: Text(l10n.saveButton)),
          ],
        ),
      ],
    );
  }
}
