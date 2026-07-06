package com.lifey.trainer;

import com.lifey.trainer.entity.WorkoutSchedule;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface WorkoutScheduleRepository extends JpaRepository<WorkoutSchedule, Long> {

    List<WorkoutSchedule> findByTrainerIdAndClientIdAndCancelledAtIsNullOrderByStartDateDesc(Long trainerId, Long clientId);

    /** Ownership-scoped lookup for schedule mutations — empty (not a 403) if it belongs to another trainer. */
    Optional<WorkoutSchedule> findByIdAndTrainerId(Long id, Long trainerId);

    /** Used by the trainer-client disconnect hook to cancel every still-active schedule for the pair. */
    List<WorkoutSchedule> findByTrainerIdAndClientIdAndCancelledAtIsNull(Long trainerId, Long clientId);
}
