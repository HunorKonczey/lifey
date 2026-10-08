package com.lifey.trainer.service;

import com.lifey.nutrition.meal.dto.MealResponse;

public interface MealCommentService {

    /**
     * Upserts the trainer's comment on one of a client's meals (LIF-144). Creates or edits — the caller doesn't need to
     * know which. The client is told by push the first time a meal gets a comment, not on every edit.
     */
    MealResponse upsertComment(Long trainerId, Long clientId, Long mealId, String comment);

    /** Clears the comment, its timestamp, and its author. */
    MealResponse deleteComment(Long trainerId, Long clientId, Long mealId);
}
