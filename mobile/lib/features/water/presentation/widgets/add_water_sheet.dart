import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/error_message.dart';
import '../../../dashboard/application/dashboard_controller.dart';
import '../../application/water_source_controller.dart';
import '../../data/water_entry_repository.dart';
import '../../domain/water_source.dart';

/// Bottom sheet for logging water intake: one-tap quick-add from a saved
/// source, or a custom amount (preset chips or a free-form liter value).
/// Pops on success; the dashboard's daily total refreshes automatically.
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

  String _sourceKey(int sourceId) => 'source:$sourceId';
  String _amountKey(double amount) => 'amount:$amount';
  static const _customKey = 'custom';

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _log({required double liters, int? sourceId, required String loadingKey}) async {
    if (_loading != null) return;
    setState(() {
      _loading = loadingKey;
      _error = null;
    });
    try {
      await ref.read(waterEntryRepositoryProvider).create(
            consumedAt: DateTime.now(),
            sourceId: sourceId,
            volumeLiters: liters,
          );
      await ref.read(dashboardControllerProvider.notifier).refresh();
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
      setState(() => _error = 'Enter a valid amount in liters');
      return;
    }
    await _log(liters: parsed, loadingKey: _customKey);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sourcesState = ref.watch(waterSourceControllerProvider);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + viewInsets),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Log water', style: theme.textTheme.titleLarge),
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
                  Text('Saved sources', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final source in sources)
                        _SourceChip(
                          source: source,
                          loading: _loading == _sourceKey(source.id),
                          onTap: () => _log(
                            liters: source.volumeLiters,
                            sourceId: source.id,
                            loadingKey: _sourceKey(source.id),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),
          Text('Custom amount', style: theme.textTheme.labelLarge),
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
                  label: Text('${amount}L'),
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
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    suffixText: 'L',
                    border: OutlineInputBorder(),
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
                    : const Text('Add'),
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
    return ActionChip(
      avatar: loading
          ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.water_drop, size: 18),
      label: Text('${source.name} · ${source.volumeLiters.toStringAsFixed(2)}L'),
      onPressed: onTap,
    );
  }
}
