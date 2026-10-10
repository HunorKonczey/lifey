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

    /**
     * Occurrences of live schedules that were not started and not yet announced as missed, for the trainer of that schedule
     * while the relationship is still ACTIVE (docs/85-trainer-push-plan.md). The predicate matches the compliance flag's
     * "missed" ({@code WorkoutScheduleServiceImpl.occurrenceStatus}); {@code from}/{@code to} is a wide UTC-date net, the
     * per-trainer "is it 08:00 of the next day yet" decision is the job's.
     */
    @Query("""
            select new com.lifey.trainer.MissedOccurrence(s.id, s.scheduledFor, s.templateName, t.id, t.utcOffsetMinutes,
                                                          c.id, c.email, c.firstName, c.lastName)
            from WorkoutSession s
            join WorkoutSchedule ws on s.scheduleId = ws.id
            join ws.trainer t
            join ws.client c
            where s.startedAt is null
              and s.deletedAt is null
              and s.missedNotifiedAt is null
              and s.scheduledFor between :from and :to
              and ws.cancelledAt is null
              and exists (select 1 from TrainerClient tc
                          where tc.trainer.id = t.id and tc.client.id = c.id
                            and tc.status = com.lifey.trainer.TrainerClientStatus.ACTIVE)
            order by t.id, s.scheduledFor, s.id
            """)
    List<MissedOccurrence> findMissedOccurrenceCandidates(@Param("from") LocalDate from, @Param("to") LocalDate to);

    /** (template, client) pairs of this trainer's schedules that are not cancelled and have not ended (LIF-106). */
    @Query("select ws.sourceTemplateId as templateId, ws.client.id as clientId from WorkoutSchedule ws "
            + "where ws.trainer.id = :trainerId and ws.cancelledAt is null and ws.endDate >= :today")
    List<TemplateClientPair> findLivePairs(@Param("trainerId") Long trainerId, @Param("today") LocalDate today);
}
