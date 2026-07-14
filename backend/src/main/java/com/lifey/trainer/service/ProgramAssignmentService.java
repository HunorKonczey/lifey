package com.lifey.trainer.service;

import com.lifey.trainer.dto.ProgramAssignmentRequest;
import com.lifey.trainer.dto.ProgramAssignmentResponse;
import com.lifey.trainer.dto.ProgramAssignmentSummaryResponse;

import java.util.List;

public interface ProgramAssignmentService {

    /** Materializes every slot as an upcoming {@code workout_sessions} occurrence for the client. */
    ProgramAssignmentResponse assign(Long programId, ProgramAssignmentRequest request);

    List<ProgramAssignmentSummaryResponse> findForClient(Long clientId);

    /** Soft-deletes the assignment's future, not-yet-started occurrences; past occurrences are untouched. */
    void cancel(Long assignmentId);

    /** Used by the trainer-client disconnect hook to cancel every still-active assignment for the pair. */
    void cancelActiveAssignmentsForPair(Long trainerId, Long clientId);
}
