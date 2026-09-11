import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../recipes/application/recipes_controller.dart';
import '../../../workouts/application/workout_template_controller.dart';
import '../domain/assignment.dart';

/// Everything this trainer can hand out, from the app's own offline-first
/// content — no request needed (docs/chat/41 T4: "a mobil app már ismeri
/// ezeket a listákat").
///
/// Templates and recipes without a server id are left out: they exist only on
/// this device until the outbox drains, and the assignment API addresses
/// content by server id. Offering one would produce an assignment the backend
/// cannot resolve.
final assignableContentProvider = Provider<List<AssignableContent>>((ref) {
  final templates = ref.watch(workoutTemplateControllerProvider).value ?? const [];
  final recipes = ref.watch(recipeControllerProvider).value ?? const [];

  return [
    for (final template in templates)
      if (template.id != null)
        AssignableContent(
          type: AssignableContentType.template,
          sourceId: template.id!,
          name: template.name,
        ),
    for (final recipe in recipes)
      if (recipe.id != null)
        AssignableContent(
          type: AssignableContentType.recipe,
          sourceId: recipe.id!,
          name: recipe.name,
        ),
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
});

/// Resolves an assignment's `(contentType, sourceId)` back to a name.
///
/// Returns null when the trainer has since deleted the source. The row still
/// exists — the client still has their copy — so the list says "deleted
/// content" rather than dropping a row the trainer can still revoke.
final assignedContentNameProvider =
    Provider<String? Function(AssignableContentType, int)>((ref) {
  final content = ref.watch(assignableContentProvider);
  final byKey = {
    for (final item in content) '${item.type.apiValue}:${item.sourceId}': item.name,
  };
  return (type, sourceId) => byKey['${type.apiValue}:$sourceId'];
});
