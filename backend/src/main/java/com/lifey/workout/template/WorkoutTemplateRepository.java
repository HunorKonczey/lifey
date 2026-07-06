package com.lifey.workout.template;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface WorkoutTemplateRepository extends JpaRepository<WorkoutTemplate, Long> {

    List<WorkoutTemplate> findAllByUserIdAndDeletedAtIsNullOrderByNameAsc(Long userId);

    Optional<WorkoutTemplate> findByIdAndUserId(Long id, Long userId);

    /** The client's existing live copy of a specific trainer template, if a previous assignment created one. */
    Optional<WorkoutTemplate> findByUserIdAndOriginTrainerIdAndOriginSourceIdAndDeletedAtIsNull(
            Long userId, Long originTrainerId, Long originSourceId);

    /**
     * Delta-sync feed (docs/16-delta-sync-rollout.md) — deliberately not
     * deletedAt-filtered: it must surface tombstoned rows (deletedAt set) so
     * the mobile client can remove them locally.
     */
    Page<WorkoutTemplate> findByUserIdAndUpdatedAtGreaterThanEqual(Long userId, Instant since, Pageable pageable);
}
