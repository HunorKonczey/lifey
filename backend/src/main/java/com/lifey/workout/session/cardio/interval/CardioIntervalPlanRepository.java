package com.lifey.workout.session.cardio.interval;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface CardioIntervalPlanRepository extends JpaRepository<CardioIntervalPlan, Long> {

    List<CardioIntervalPlan> findAllByUserIdAndDeletedAtIsNullOrderByNameAsc(Long userId);

    /**
     * Every read path goes through a userId-scoped finder — a plan is a
     * business entity like any other (CLAUDE.md), and there is no shared or
     * trainer-assigned interval plan.
     */
    Optional<CardioIntervalPlan> findByIdAndUserIdAndDeletedAtIsNull(Long id, Long userId);

    /**
     * Delta-sync feed (docs/16-delta-sync-rollout.md) — deliberately not
     * deletedAt-filtered: it must surface tombstoned rows (deletedAt set) so
     * the mobile client can remove them locally.
     */
    Page<CardioIntervalPlan> findByUserIdAndUpdatedAtGreaterThanEqual(Long userId, Instant since, Pageable pageable);
}
