import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/lifey_format.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_type.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/lifey_card.dart';
import '../../../../shared/widgets/origin_trainer_badge.dart';
import '../../../../shared/widgets/sync_status_indicator.dart';
import '../../application/recipe_image_controller.dart';
import '../../domain/recipe.dart';
import '../../domain/recipe_filter.dart';

/// One recipe of the Recipes tab's two-column grid (docs/redesign/
/// 77-mobile-redesign-plan.md R2.7; canvas Lifey 2 › 2.3 "Kétoszlopos rács
/// képpel").
///
/// A 4:3 photo (a striped neutral placeholder when the recipe has none) with
/// the favourite star on it, the name, "520 kcal · 46 g P" per serving in the
/// metric colours, and a full-width "+ Log" button. Tap opens the recipe,
/// long-press its menu; the star and "+ Log" are their own targets.
class RecipeGridCard extends ConsumerWidget {
  const RecipeGridCard({
    super.key,
    required this.recipe,
    required this.onTap,
    required this.onLongPress,
    required this.onLog,
    required this.onToggleFavorite,
  });

  final Recipe recipe;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onLog;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final p = context.palette;
    final mc = context.metricColors;
    final t = Theme.of(context).textTheme;
    final primary = Theme.of(context).colorScheme.primary;

    Uint8List? bytes;
    final recipeId = recipe.id;
    if (recipeId != null && recipe.imageUpdatedAt != null) {
      bytes = ref
          .watch(recipeThumbnailProvider((
            clientId: recipe.clientId,
            serverId: recipeId,
            imageUpdatedAt: recipe.imageUpdatedAt,
          )))
          .value;
    }

    final macroStyle = Theme.of(context).textTheme.bodySmall!.copyWith(height: 1.2, fontWeight: FontWeight.w700, fontFeatures: AppType.tabular);

    return LifeyCard(
      padding: const EdgeInsets.all(AppSpacing.s8),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.nested(AppRadius.card, AppSpacing.s8)),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: bytes != null
                      ? Image.memory(bytes, fit: BoxFit.cover)
                      : const RecipePhotoPlaceholder(),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  tooltip: recipe.favorite ? l10n.recipeUnfavoriteTooltip : l10n.recipeFavoriteTooltip,
                  onPressed: onToggleFavorite,
                  icon: Icon(
                    recipe.favorite ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 20,
                    color: recipe.favorite ? mc.carbs : p.text,
                  ),
                  style: IconButton.styleFrom(
                    fixedSize: const Size.square(40),
                    minimumSize: const Size.square(40),
                    backgroundColor: p.bg.withValues(alpha: 0.7),
                    shape: const CircleBorder(),
                    tapTargetSize: MaterialTapTargetSize.padded,
                  ),
                ),
              ),
              Positioned(left: AppSpacing.s4, top: AppSpacing.s4, child: SyncStatusIndicator(clientId: recipe.clientId)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s4, AppSpacing.s12, AppSpacing.s4, AppSpacing.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipe.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleMedium!.copyWith(height: 1.25, color: p.text),
                ),
                const SizedBox(height: AppSpacing.s4),
                Wrap(
                  spacing: AppSpacing.s12,
                  runSpacing: 2,
                  children: [
                    Text('${f.kcal(caloriesPerServing(recipe))} kcal', style: macroStyle.copyWith(color: mc.calories)),
                    Text(
                      '${f.grams(proteinPerServing(recipe))} g ${l10n.macroLetterProtein}',
                      style: macroStyle.copyWith(color: mc.protein),
                    ),
                  ],
                ),
                if (recipe.originTrainerId != null) ...[
                  const SizedBox(height: AppSpacing.s8),
                  OriginTrainerBadge(originTrainerId: recipe.originTrainerId!),
                ],
              ],
            ),
          ),
          const Spacer(),
          Material(
            color: p.nested,
            borderRadius: BorderRadius.circular(AppRadius.control),
            child: InkWell(
              onTap: onLog,
              borderRadius: BorderRadius.circular(AppRadius.control),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 20, color: primary),
                      const SizedBox(width: AppSpacing.s4),
                      // Shrinks rather than overflows in a narrow card at
                      // large text ("Naplózás" at 130 %).
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            l10n.recipeLogAction,
                            maxLines: 1,
                            style: t.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What an image-less recipe shows: diagonal neutral stripes with a quiet
/// icon, as the canvas draws its "recipe photo" placeholder.
class RecipePhotoPlaceholder extends StatelessWidget {
  const RecipePhotoPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return CustomPaint(
      painter: _StripePainter(base: p.nested, stripe: p.control),
      child: Center(child: Icon(Icons.restaurant_menu_rounded, size: 32, color: p.text3)),
    );
  }
}

class _StripePainter extends CustomPainter {
  _StripePainter({required this.base, required this.stripe});

  final Color base;
  final Color stripe;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = base);
    final paint = Paint()
      ..color = stripe
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke;
    const gap = 20.0;
    // 45° stripes across the whole box.
    for (var x = -size.height; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_StripePainter old) => old.base != base || old.stripe != stripe;
}
