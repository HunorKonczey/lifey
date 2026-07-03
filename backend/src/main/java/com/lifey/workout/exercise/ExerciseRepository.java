package com.lifey.workout.exercise;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface ExerciseRepository extends JpaRepository<Exercise, Long> {

    List<Exercise> findAllByUserIdAndDeletedAtIsNullOrderByNameAsc(Long userId);

    /**
     * Delta-sync feed (docs/16-delta-sync-rollout.md) — deliberately not
     * deletedAt-filtered so tombstoned rows (deletedAt set) surface for the
     * mobile client to remove locally.
     */
    Page<Exercise> findByUserIdAndUpdatedAtGreaterThanEqual(Long userId, Instant since, Pageable pageable);

    Optional<Exercise> findByIdAndUserId(Long id, Long userId);

    /** Dedupe lookup for the trainer content-assignment deep copy (see ContentAssignmentServiceImpl). */
    Optional<Exercise> findByUserIdAndOriginTrainerIdAndOriginSourceIdAndDeletedAtIsNull(
            Long userId, Long originTrainerId, Long originSourceId);
}
