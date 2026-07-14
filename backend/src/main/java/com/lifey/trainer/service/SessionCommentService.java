package com.lifey.trainer.service;

import com.lifey.workout.session.dto.WorkoutSessionResponse;

public interface SessionCommentService {

    /**
     * Upserts the trainer's comment on a client's session
     * (docs/31-session-feedback-loop-plan.md, B2). Creates or edits — the
     * caller doesn't need to know which.
     */
    WorkoutSessionResponse upsertComment(Long trainerId, Long clientId, Long sessionId, String comment);

    /** Clears the comment, its timestamp, and its author. */
    WorkoutSessionResponse deleteComment(Long trainerId, Long clientId, Long sessionId);
}
