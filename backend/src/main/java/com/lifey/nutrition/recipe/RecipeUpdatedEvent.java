package com.lifey.nutrition.recipe;

/**
 * Published after a trainer's own recipe is edited, to push the change to
 * every client's already-assigned copy (see
 * {@code com.lifey.trainer.AssignedContentSyncListener}). Unlike
 * {@code UserRegisteredEvent}, this is only ever consumed synchronously in the
 * same transaction/thread that published it — the listener does not need to
 * defensively re-fetch or re-check existence, the source row was just
 * updated. Do not switch its listener to {@code @TransactionalEventListener}
 * (AFTER_COMMIT): propagation must be part of the same atomic edit.
 */
public record RecipeUpdatedEvent(Long trainerId, Long recipeId) {
}
