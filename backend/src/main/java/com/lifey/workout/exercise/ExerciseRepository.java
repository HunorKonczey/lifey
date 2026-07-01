package com.lifey.workout.exercise;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.List;

public interface ExerciseRepository extends JpaRepository<Exercise, Long> {

    List<Exercise> findAllByDeletedAtIsNullOrderByNameAsc();

    /**
     * Delta-sync feed (docs/16-delta-sync-rollout.md) — global like Foods, no
     * userId filter; deliberately not deletedAt-filtered so tombstoned rows
     * (deletedAt set) surface for the mobile client to remove locally.
     */
    Page<Exercise> findByUpdatedAtGreaterThanEqual(Instant since, Pageable pageable);
}
