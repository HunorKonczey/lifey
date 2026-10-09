package com.lifey.trainer;

import com.lifey.trainer.entity.WorkoutSchedule;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface WorkoutScheduleRepository extends JpaRepository<WorkoutSchedule, Long> {

    List<WorkoutSchedule> findByTrainerIdAndClientIdAndCancelledAtIsNullOrderByStartDateDesc(Long trainerId, Long clientId);

    /** Ownership-scoped lookup for schedule mutations — empty (not a 403) if it belongs to another trainer. */
    Optional<WorkoutSchedule> findByIdAndTrainerId(Long id, Long trainerId);

    /** Used by the trainer-client disconnect hook to cancel every still-active schedule for the pair. */
    List<WorkoutSchedule> findByTrainerIdAndClientIdAndCancelledAtIsNull(Long trainerId, Long clientId);

    /** (template, client) pairs of this trainer's schedules that are not cancelled and have not ended (LIF-106). */
    @Query("select ws.sourceTemplateId as templateId, ws.client.id as clientId from WorkoutSchedule ws "
            + "where ws.trainer.id = :trainerId and ws.cancelledAt is null and ws.endDate >= :today")
    List<TemplateClientPair> findLivePairs(@Param("trainerId") Long trainerId, @Param("today") LocalDate today);
}
