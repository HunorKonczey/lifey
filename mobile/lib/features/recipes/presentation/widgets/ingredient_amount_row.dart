import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../l10n/app_localizations.dart';

/// One ingredient of a recipe being logged: its name and an editable amount in
/// grams. Shared by `LogRecipeSheet` and the Add-recipe sheet. A reset button
/// appears while the amount was typed by hand ([overridden]).
class IngredientAmountRow extends StatelessWidget {
  const IngredientAmountRow({
    super.key,
    required this.name,
    required this.controller,
    required this.overridden,
    required this.enabled,
    required this.onChanged,
    required this.onReset,
  });

  final String name;
  final TextEditingController controller;
  final bool overridden;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (overridden)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: l10n.resetIngredientTooltip,
              onPressed: enabled ? onReset : null,
              icon: const Icon(Icons.restart_alt, size: 20),
            ),
          const SizedBox(width: 8),
          SizedBox(
            width: 88,
            child: TextField(
              controller: controller,
              enabled: enabled,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
              ],
              textAlign: TextAlign.end,
              decoration: const InputDecoration(
                isDense: true,
                suffixText: 'g',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
