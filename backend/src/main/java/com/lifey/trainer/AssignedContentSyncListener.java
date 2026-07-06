package com.lifey.trainer;

import com.lifey.nutrition.recipe.RecipeUpdatedEvent;
import com.lifey.trainer.service.ContentAssignmentService;
import com.lifey.workout.template.WorkoutTemplateUpdatedEvent;
import lombok.RequiredArgsConstructor;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

/**
 * Live-syncs a trainer's template/recipe edit to every client's
 * already-assigned copy. Deliberately plain {@code @EventListener} rather than
 * {@code @TransactionalEventListener}(AFTER_COMMIT) like the auth package's
 * listeners: this must run inside the same transaction as the triggering
 * edit, so a propagation failure rolls back the trainer's own edit too rather
 * than leaving some clients' copies stale — no try/catch here on purpose.
 */
@Component
@RequiredArgsConstructor
class AssignedContentSyncListener {

    private final ContentAssignmentService contentAssignmentService;

    @EventListener
    void onWorkoutTemplateUpdated(WorkoutTemplateUpdatedEvent event) {
        contentAssignmentService.propagateTemplateUpdate(event.trainerId(), event.templateId());
    }

    @EventListener
    void onRecipeUpdated(RecipeUpdatedEvent event) {
        contentAssignmentService.propagateRecipeUpdate(event.trainerId(), event.recipeId());
    }
}
