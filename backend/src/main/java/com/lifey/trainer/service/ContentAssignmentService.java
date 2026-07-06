package com.lifey.trainer.service;

import com.lifey.trainer.ContentType;
import com.lifey.trainer.dto.AssignmentListItemResponse;
import com.lifey.trainer.dto.AssignmentRequest;
import com.lifey.trainer.dto.AssignmentResponse;

import java.util.List;

public interface ContentAssignmentService {

    AssignmentResponse assign(AssignmentRequest request);

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
