import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/food_controller.dart';
import '../../application/meal_estimation_controller.dart';
import '../../domain/meal_estimate.dart';
import 'add_meal_entry_sheet.dart';

/// Sends [imagePath] to the AI estimate and lets the user review the result
/// (docs/23-ai-calorie-estimation-plan.md "Mobile"): every item's name,
/// portion, calories and macros are editable and removable. Confirming saves
/// each item as a hidden food — the same way [AddMacrosSheet] does — and pops
/// with one [MealEntryDraft] per item, so the meal is saved through the normal
/// offline-first path. Only the estimate itself needs the network.
///
/// Pops with `null` when dismissed or when the estimate can't be used. On a
/// 402 the caller reads [mealEstimationControllerProvider] and opens the
/// paywall — this sheet's context is gone by then.
class MealEstimateSheet extends ConsumerStatefulWidget {
  const MealEstimateSheet({super.key, required this.imagePath});

  final String imagePath;

  @override
  ConsumerState<MealEstimateSheet> createState() => _MealEstimateSheetState();
}

class _MealEstimateSheetState extends ConsumerState<MealEstimateSheet> {
  final _formKey = GlobalKey<FormState>();
  List<_EditableItem>? _items;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _estimate());
  }

  @override
  void dispose() {
    for (final item in _items ?? const <_EditableItem>[]) {
      item.dispose();
    }
    super.dispose();
  }

  void _estimate() {
    ref.read(mealEstimationControllerProvider.notifier).estimate(widget.imagePath);
  }

  Future<void> _submit() async {
    final items = _items;
    if (_submitting || items == null || items.isEmpty) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final foods = ref.read(foodControllerProvider.notifier);
      final drafts = <MealEntryDraft>[];
      for (final item in items) {
        final grams = _parse(item.grams.text)!;
        // Back-calculate per-100 g so that stored × grams / 100 reproduces
        // the reviewed portion totals — same math as AddMacrosSheet.
        final factor = 100.0 / grams;
        final food = await foods.addFood(
          name: item.name.text.trim(),
          calories: _parse(item.calories.text)! * factor,
          protein: _parse(item.protein.text)! * factor,
          carbs: _parse(item.carbs.text)! * factor,
          fat: _parse(item.fat.text)! * factor,
          hidden: true,
        );
        drafts.add((food: food, grams: grams));
      }
      if (mounted) Navigator.of(context).pop<List<MealEntryDraft>>(drafts);
    } catch (_) {
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context)!.couldNotSaveFoodMessage);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _removeItem(_EditableItem item) {
    setState(() => _items!.remove(item));
    // Its fields are still attached until this rebuild lands.
    WidgetsBinding.instance.addPostFrameCallback((_) => item.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mealEstimationControllerProvider);
    ref.listen(mealEstimationControllerProvider, (_, next) {
      if (next is MealEstimationDone) {
        setState(() => _items = next.estimate.items.map(_EditableItem.new).toList());
      } else if (next is MealEstimationCreditsExhausted) {
        Navigator.of(context).pop();
      }
    });

    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + viewInsets),
        child: switch (state) {
          MealEstimationDone(:final estimate) when _items != null =>
            _buildResult(context, estimate),
          MealEstimationOffline() => _StatusView(
              imagePath: widget.imagePath,
              message: AppLocalizations.of(context)!.mealEstimateOfflineMessage,
              onRetry: _estimate,
            ),
          MealEstimationFailed() => _StatusView(
              imagePath: widget.imagePath,
              message: AppLocalizations.of(context)!.mealEstimateFailedMessage,
              onRetry: _estimate,
            ),
          _ => _StatusView(
              imagePath: widget.imagePath,
              message: AppLocalizations.of(context)!.mealEstimateLoadingMessage,
              loading: true,
            ),
        },
      ),
    );
  }

  Widget _buildResult(BuildContext context, MealEstimate estimate) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final items = _items!;

    if (items.isEmpty) {
      return _StatusView(
        imagePath: widget.imagePath,
        message: estimate.items.isEmpty
            ? l10n.mealEstimateNoFoodMessage
            : l10n.mealEstimateAllRemovedMessage,
        notes: estimate.items.isEmpty ? estimate.notes : null,
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Thumbnail(imagePath: widget.imagePath, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.mealEstimateSheetTitle, style: theme.textTheme.titleLarge),
                    Text(
                      l10n.mealEstimateReviewHint,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (estimate.notes != null) ...[
            const SizedBox(height: 8),
            Text(
              estimate.notes!,
              style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 12),
          // Not a lazy ListView: the form has to validate every item, and
          // a field that was never built can't be validated (at most 20).
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final item in items)
                    Padding(
                      key: ObjectKey(item),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ItemCard(item: item, onRemove: () => _removeItem(item)),
                    ),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.mealEstimateAddItemsButton(items.length)),
          ),
        ],
      ),
    );
  }
}

double? _parse(String text) => double.tryParse(text.replaceAll(',', '.').trim());

/// Whole numbers without a trailing ".0"; otherwise one decimal.
String _format(double value) {
  final rounded = (value * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
}

/// One estimated item's editable fields. Changing the portion rescales
/// calories and macros with it — the model's per-gram ratio is the part it is
/// best at; the portion is the part users most often correct.
class _EditableItem {
  _EditableItem(EstimatedItem item)
      : confidence = item.confidence,
        name = TextEditingController(text: item.name),
        grams = TextEditingController(text: _format(item.grams)),
        calories = TextEditingController(text: _format(item.calories)),
        protein = TextEditingController(text: _format(item.protein)),
        carbs = TextEditingController(text: _format(item.carbs)),
        fat = TextEditingController(text: _format(item.fat)),
        _lastGrams = item.grams;

  final EstimateConfidence confidence;
  final TextEditingController name;
  final TextEditingController grams;
  final TextEditingController calories;
  final TextEditingController protein;
  final TextEditingController carbs;
  final TextEditingController fat;
  double _lastGrams;

  void onGramsChanged(String text) {
    final next = _parse(text);
    if (next == null || next <= 0 || _lastGrams <= 0) return;
    final factor = next / _lastGrams;
    for (final field in [calories, protein, carbs, fat]) {
      final value = _parse(field.text);
      if (value != null) field.text = _format(value * factor);
    }
    _lastGrams = next;
  }

  void dispose() {
    for (final c in [name, grams, calories, protein, carbs, fat]) {
      c.dispose();
    }
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.onRemove});

  final _EditableItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    String? requiredPositive(String? v) {
      final parsed = _parse(v ?? '');
      if (parsed == null) return l10n.enterANumberError;
      if (parsed <= 0) return l10n.mustBeGreaterThanZeroError;
      return null;
    }

    String? requiredNonNegative(String? v) {
      final parsed = _parse(v ?? '');
      if (parsed == null) return l10n.enterANumberError;
      if (parsed < 0) return l10n.mustBeZeroOrMoreError;
      return null;
    }

    Widget number(TextEditingController c, String label, String suffix,
        String? Function(String?) validator,
        {ValueChanged<String>? onChanged}) {
      return TextFormField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        validator: validator,
        onChanged: onChanged,
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: item.name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l10n.nameLabel,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l10n.requiredFieldError : null,
                ),
              ),
              IconButton(
                tooltip: l10n.mealEstimateRemoveItemTooltip,
                icon: const Icon(Icons.close),
                onPressed: onRemove,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: number(item.grams, l10n.quantityLabel, 'g', requiredPositive,
                          onChanged: item.onGramsChanged),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: number(
                          item.calories, l10n.caloriesLabel, 'kcal', requiredNonNegative),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child:
                          number(item.protein, l10n.proteinLabel, 'g', requiredNonNegative),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: number(item.carbs, l10n.carbsLabel, 'g', requiredNonNegative),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: number(item.fat, l10n.fatLabel, 'g', requiredNonNegative),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _ConfidenceBadge(confidence: item.confidence),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.confidence});

  final EstimateConfidence confidence;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final (label, icon) = switch (confidence) {
      EstimateConfidence.high => (l10n.mealEstimateConfidenceHigh, Icons.check_circle_outline),
      EstimateConfidence.medium => (l10n.mealEstimateConfidenceMedium, Icons.help_outline),
      EstimateConfidence.low => (l10n.mealEstimateConfidenceLow, Icons.error_outline),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Loading, error, and empty states: the photo, a message, and optionally a
/// retry. No credit is used by any of them (the server only counts a
/// successful call), so retrying is free.
class _StatusView extends StatelessWidget {
  const _StatusView({
    required this.imagePath,
    required this.message,
    this.notes,
    this.loading = false,
    this.onRetry,
  });

  final String imagePath;
  final String message;
  final String? notes;
  final bool loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Thumbnail(imagePath: imagePath, size: 120),
        const SizedBox(height: 16),
        if (loading) ...[
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
        ],
        Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
        if (notes != null) ...[
          const SizedBox(height: 8),
          Text(
            notes!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: onRetry,
            child: Text(AppLocalizations.of(context)!.retryButton),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.imagePath, required this.size});

  final String imagePath;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 6),
      child: Image.file(
        File(imagePath),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => SizedBox(width: size, height: size),
      ),
    );
  }
}
