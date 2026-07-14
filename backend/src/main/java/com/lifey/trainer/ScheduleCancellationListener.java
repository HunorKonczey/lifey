package com.lifey.trainer;

import com.lifey.trainer.service.ProgramAssignmentService;
import com.lifey.trainer.service.WorkoutScheduleService;
import lombok.RequiredArgsConstructor;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

/**
 * Cancels a trainer-client pair's active schedules and program assignments
 * when the relationship is revoked (docs/personal_trainer/
 * 08-utemezett-edzesek-koncepcio.md, "Folyamat — lemondás és bontás", point 4;
 * program assignments added by docs/34-multi-week-program-plan.md). Plain
 * {@code @EventListener}, not {@code @TransactionalEventListener}(AFTER_COMMIT)
 * — same rationale as {@link AssignedContentSyncListener}: this must run
 * inside the same transaction as the revoke itself.
 */
@Component
@RequiredArgsConstructor
class ScheduleCancellationListener {

    private final WorkoutScheduleService workoutScheduleService;
    private final ProgramAssignmentService programAssignmentService;

    @EventListener
    void onTrainerClientRevoked(TrainerClientRevokedEvent event) {
        workoutScheduleService.cancelActiveSchedulesForPair(event.trainerId(), event.clientId());
        programAssignmentService.cancelActiveAssignmentsForPair(event.trainerId(), event.clientId());
    }
}
