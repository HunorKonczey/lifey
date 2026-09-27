import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/lifey_format.dart';
import '../../../../core/network/error_message.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_type.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/lifey_sheet.dart';
import '../../../../shared/widgets/ds/section_label.dart';
import '../../../../shared/widgets/ds/tinted_chip.dart';
import '../../../settings/application/settings_controller.dart';
import '../../application/water_source_controller.dart';
import '../../data/water_entry_repository.dart';
import '../../domain/water_source.dart';

/// Opens the "Add water" sheet (canvas "BOTTOM SHEET": the title with today's
/// "0.99 / 2.60 L" in the water colour, then three tinted 64 px amount tiles;
/// docs/redesign/77-mobile-redesign-plan.md R1.7). Covers the bottom nav.
Future<void> showAddWaterSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showLifeySheet<void>(
    context: context,
    useRootNavigator: true,
    title: l10n.addWaterTitle,
    trailing: const _TodayTotal(),
    builder: (_) => const AddWaterSheet(),
  );
}

/// "0.99 / 2.60 L" — today's total against the goal, 13/600 in the water
/// colour; just "0.99 L" without a goal. Live: it follows the entries table.
class _TodayTotal extends ConsumerWidget {
  const _TodayTotal();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final total = ref.watch(todayWaterTotalProvider).value ?? 0;
    final goal = ref.watch(settingsControllerProvider).value?.dailyWaterGoalLiters;
    final text = (goal != null && goal > 0)
        ? '${f.decimal(total, 2)} ${l10n.dashboardWaterOfGoal(f.decimal(goal, 2))}'
        : '${f.decimal(total, 2)} L';
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall!.copyWith(fontWeight: FontWeight.w600, height: 1, fontFeatures: AppType.tabular, color: context.metricColors.water),
    );
  }
}

/// The body of the "Add water" sheet: one-tap quick amounts, the saved
/// sources, and a custom amount. Pops on success; the dashboard's daily total
/// updates on its own (it reads the local water_entries table live — see
/// `todayWaterTotalProvider`).
class AddWaterSheet extends ConsumerStatefulWidget {
  const AddWaterSheet({super.key});

  @override
  ConsumerState<AddWaterSheet> createState() => _AddWaterSheetState();
}

class _AddWaterSheetState extends ConsumerState<AddWaterSheet> {
  static const quickAmounts = [0.25, 0.5, 1.0];

  final _amountController = TextEditingController();

  /// Tracks which action is in flight (string-prefixed so a source id can
  /// never collide with a quick-amount value) so only that control shows a
  /// spinner instead of disabling the whole sheet.
  String? _loading;
  String? _error;

  String _sourceKey(String sourceId) => 'source:$sourceId';
  String _amountKey(double amount) => 'amount:$amount';
  static const _customKey = 'custom';

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _log(
      {required double liters, String? sourceClientId, required String loadingKey}) async {
    if (_loading != null) return;
    setState(() {
      _loading = loadingKey;
      _error = null;
    });
    try {
      await ref.read(waterEntryRepositoryProvider).create(
            consumedAt: DateTime.now(),
            sourceClientId: sourceClientId,
            volumeLiters: liters,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(() {
        _error = friendlyError(error);
        _loading = null;
      });
    }
  }

  Future<void> _logCustomAmount() async {
    final text = _amountController.text.replaceAll(',', '.').trim();
    final parsed = double.tryParse(text);
    if (parsed == null || parsed <= 0) {
      setState(() => _error = AppLocalizations.of(context)!.enterValidAmountError);
      return;
    }
    await _log(liters: parsed, loadingKey: _customKey);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final sources = ref.watch(waterSourceControllerProvider).value ?? const <WaterSource>[];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Quick amounts: three tiles, one tap logs ─────────────────────
        Row(
          children: [
            for (final (i, amount) in quickAmounts.indexed) ...[
              if (i > 0) const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: _AmountTile(
                  value: f.litres(amount),
                  loading: _loading == _amountKey(amount),
                  onTap: () => _log(liters: amount, loadingKey: _amountKey(amount)),
                ),
              ),
            ],
          ],
        ),

        // ── Saved sources ────────────────────────────────────────────────
        if (sources.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s20),
          SectionLabel(l10n.savedSourcesLabel),
          const SizedBox(height: AppSpacing.s8),
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              for (final source in sources)
                ActionChip(
                  avatar: _loading == _sourceKey(source.clientId)
                      ? const SizedBox(
                          height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(Icons.water_drop_rounded, size: 18, color: context.metricColors.water),
                  label: Text(l10n.sourceChipLabel(source.name, f.litres(source.volumeLiters))),
                  onPressed: () => _log(
                    liters: source.volumeLiters,
                    sourceClientId: source.clientId,
                    loadingKey: _sourceKey(source.clientId),
                  ),
                ),
            ],
          ),
        ],

        // ── Custom amount ────────────────────────────────────────────────
        const SizedBox(height: AppSpacing.s20),
        SectionLabel(l10n.customAmountLabel),
        const SizedBox(height: AppSpacing.s8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(labelText: l10n.amountLabel, suffixText: 'L'),
                onSubmitted: (_) => _logCustomAmount(),
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            FilledButton(
              onPressed: _loading != null ? null : _logCustomAmount,
              style: FilledButton.styleFrom(minimumSize: const Size(88, 52)),
              child: _loading == _customKey
                  ? const SizedBox(
                      height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.addButton),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.s8),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
      ],
    );
  }
}

/// One of the three quick amounts: 64 px tall, the water colour at its chip
/// tint, the amount 18/800 in the water colour over a 12/600 "L".
class _AmountTile extends StatelessWidget {
  const _AmountTile({required this.value, required this.loading, required this.onTap});

  final String value;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final water = context.metricColors.water;
    final p = context.palette;
    final tint = TintedChip.tintAlpha(Theme.of(context).brightness);
    return Semantics(
      button: true,
      label: '$value L',
      excludeSemantics: true,
      child: Material(
        color: water.withValues(alpha: tint),
        borderRadius: AppRadius.controlAll,
        child: InkWell(
          onTap: loading ? null : onTap,
          borderRadius: AppRadius.controlAll,
          child: SizedBox(
            height: 64,
            child: Center(
              child: loading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: water),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(value,
                            style: AppType.number(18, color: water).copyWith(letterSpacing: 0)),
                        const SizedBox(height: 2),
                        Text('L',
                            style: Theme.of(context).textTheme.labelSmall!.copyWith(
                                fontWeight: FontWeight.w600, height: 1, color: p.text2)),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
