package com.lifey.trainer;

import com.lifey.trainer.entity.ProgramAssignment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface ProgramAssignmentRepository extends JpaRepository<ProgramAssignment, Long> {

    List<ProgramAssignment> findByTrainerIdAndClientIdOrderByStartDateDesc(Long trainerId, Long clientId);

    /** Ownership-scoped lookup for assignment mutations — empty (not a 403) if it belongs to another trainer. */
    Optional<ProgramAssignment> findByIdAndTrainerId(Long id, Long trainerId);

    /** Used by the trainer-client disconnect hook to cancel every still-active program assignment for the pair. */
    List<ProgramAssignment> findByTrainerIdAndClientIdAndCancelledAtIsNull(Long trainerId, Long clientId);

    /** Guards against re-starting the same program for a client while an existing run is still active. */
    boolean existsByProgramIdAndClientIdAndCancelledAtIsNullAndEndDateGreaterThanEqual(
            Long programId, Long clientId, LocalDate today);

    /**
     * (template, client) pairs of this trainer's program assignments that are not cancelled and have not ended: every
     * template the assigned program uses, for every client running it (LIF-106).
     */
    @Query("select pw.template.id as templateId, pa.client.id as clientId from ProgramAssignment pa, ProgramWorkout pw "
            + "where pw.program.id = pa.program.id and pa.trainer.id = :trainerId "
            + "and pa.cancelledAt is null and pa.endDate >= :today")
    List<TemplateClientPair> findLivePairs(@Param("trainerId") Long trainerId, @Param("today") LocalDate today);

    /** Across every client — backs the program list's "active assignments" count. */
    int countByProgramIdAndCancelledAtIsNullAndEndDateGreaterThanEqual(Long programId, LocalDate today);
}
