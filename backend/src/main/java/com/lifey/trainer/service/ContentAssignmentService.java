package com.lifey.trainer.service;

import com.lifey.trainer.ContentType;
import com.lifey.trainer.dto.AssignmentListItemResponse;
import com.lifey.trainer.dto.AssignmentRequest;
import com.lifey.trainer.dto.BulkAssignmentResponse;
import com.lifey.workout.template.WorkoutTemplate;

import java.util.List;

public interface ContentAssignmentService {

    /**
     * Deep-copies the trainer's template/recipe to every requested client in
     * one transaction. Clients who already hold this content are skipped and
     * reported; a revoked client (403) or missing source (404) fails the
     * whole batch with zero writes.
     */
    BulkAssignmentResponse assign(AssignmentRequest request);

    /**
     * Reuses the client's existing live copy of this exact trainer template if
     * one already exists (from an earlier assignment, schedule or program
     * assignment); otherwise deep-copies it (recording the same
     * {@code content_assignments} fact row as {@link #assign}). Shared by
     * {@code WorkoutScheduleService} and {@code ProgramAssignmentService} —
     * scheduling/assigning a program is thus an implicit assignment.
     */
    WorkoutTemplate resolveClientCopy(Long trainerId, Long clientId, WorkoutTemplate sourceTemplate);

    List<AssignmentListItemResponse> findForClient(Long clientId);

    /** Client ids this trainer has already assigned this exact content to. */
    List<Long> findAssignedClientIds(ContentType contentType, Long sourceId);

    /** Removes the assignment and soft-deletes the client's copy it created. */
    void unassign(Long assignmentId);

    /**
     * Pushes the trainer's latest edit of this template to every client's
     * already-assigned copy (live sync — see
     * {@code com.lifey.trainer.AssignedContentSyncListener}).
     */
    void propagateTemplateUpdate(Long trainerId, Long templateId);

    /** Pushes the trainer's latest edit of this recipe to every client's already-assigned copy. */
    void propagateRecipeUpdate(Long trainerId, Long recipeId);
}
