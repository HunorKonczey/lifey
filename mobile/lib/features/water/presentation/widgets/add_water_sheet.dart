import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/error_message.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/water_source_controller.dart';
import '../../data/water_entry_repository.dart';
import '../../domain/water_source.dart';

/// Bottom sheet for logging water intake: one-tap quick-add from a saved
/// source, or a custom amount (preset chips or a free-form liter value).
/// Pops on success; the dashboard's daily total updates on its own (it reads
/// the local water_entries table live — see `todayWaterTotalProvider`).
class AddWaterSheet extends ConsumerStatefulWidget {
  const AddWaterSheet({super.key});

  @override
  ConsumerState<AddWaterSheet> createState() => _AddWaterSheetState();
}

class _AddWaterSheetState extends ConsumerState<AddWaterSheet> {
  static const _quickAmounts = [0.25, 0.5, 1.0];

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
    final sourcesState = ref.watch(waterSourceControllerProvider);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + viewInsets),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.logWaterTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          sourcesState.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (sources) {
              if (sources.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.savedSourcesLabel, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final source in sources)
                        _SourceChip(
                          source: source,
                          loading: _loading == _sourceKey(source.clientId),
                          onTap: () => _log(
                            liters: source.volumeLiters,
                            sourceClientId: source.clientId,
                            loadingKey: _sourceKey(source.clientId),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),
          Text(l10n.customAmountLabel, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final amount in _quickAmounts)
                ActionChip(
                  avatar: _loading == _amountKey(amount)
                      ? const SizedBox(
                          height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.add, size: 18),
                  label: Text(l10n.amountLitersLabel(amount.toString())),
                  onPressed: () => _log(liters: amount, loadingKey: _amountKey(amount)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: l10n.amountLabel,
                    suffixText: 'L',
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _logCustomAmount(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _loading != null ? null : _logCustomAmount,
                child: _loading == _customKey
                    ? const SizedBox(
                        height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.addButton),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
        ],
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.source, required this.loading, required this.onTap});

  final WaterSource source;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ActionChip(
      avatar: loading
          ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.water_drop, size: 18),
      label: Text(l10n.sourceChipLabel(source.name, source.volumeLiters.toStringAsFixed(2))),
      onPressed: onTap,
    );
  }
}
