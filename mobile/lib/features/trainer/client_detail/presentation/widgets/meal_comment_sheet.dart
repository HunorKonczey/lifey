import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/widgets/ds/lifey_sheet.dart';
import '../../application/client_sessions_controller.dart' show CommentSaveOutcome;
import '../../data/client_detail_repository.dart';
import '../../domain/client_data.dart';
import 'comment_editor_sheet.dart';

/// The trainer's comment on one of a client's meals (LIF-144). The write goes straight to the repository: a meal is
/// read per day, so the tab refreshes that day after the sheet closes instead of keeping a controller for it.
class MealCommentSheet extends ConsumerWidget {
  const MealCommentSheet({super.key, required this.clientId, required this.meal});

  final int clientId;
  final ClientMeal meal;

  /// Returns the outcome once the server has confirmed it, or null if the trainer backed out.
  static Future<CommentSaveOutcome?> show(
    BuildContext context, {
    required int clientId,
    required ClientMeal meal,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return showLifeySheet<CommentSaveOutcome>(
      context: context,
      title: meal.hasTrainerComment ? l10n.trainerEditCommentTitle : l10n.trainerAddCommentTitle,
      useRootNavigator: true,
      builder: (_) => MealCommentSheet(clientId: clientId, meal: meal),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final repository = ref.read(clientDetailRepositoryProvider);
    return CommentEditorSheet(
      initialComment: meal.trainerComment,
      subtitle: l10n.trainerMealCommentSheetSubtitle,
      hint: l10n.trainerMealCommentHint,
      onSave: (text) async {
        await repository.putMealComment(clientId, meal.id, text);
        return meal.hasTrainerComment ? CommentSaveOutcome.updated : CommentSaveOutcome.created;
      },
      onDelete: () async {
        await repository.deleteMealComment(clientId, meal.id);
        return CommentSaveOutcome.removed;
      },
    );
  }
}
