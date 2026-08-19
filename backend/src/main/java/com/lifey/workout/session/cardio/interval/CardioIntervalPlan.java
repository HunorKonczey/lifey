package com.lifey.workout.session.cardio.interval;

import com.lifey.common.domain.SyncableEntity;
import com.lifey.user.User;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.util.ArrayList;
import java.util.List;

/**
 * A reusable interval plan for the indoor bike — "4×4 perc kemény / 3 perc
 * könnyű" (docs/cardio/60 D-C7.1). Owned by a user, like every other business
 * entity (CLAUDE.md).
 *
 * <p>The plan is a blueprint only: running it writes {@code cardio_splits}
 * rows on the session (see {@code SplitType#INTERVAL}), which carry their own
 * durations and intensities. Nothing points from a session back to a plan, so
 * deleting a plan can never touch the sessions run with it, and editing one
 * can never rewrite what a past summary shows.
 *
 * <p>Only the parent plan is delta-synced (docs/16-delta-sync-rollout.md) —
 * {@link #steps} are never independently tombstoned, so a step-only edit must
 * explicitly bump {@code updatedAt}, same as WorkoutTemplate's exercise links
 * already require.
 */
@Getter
@Setter
@Entity
@Table(name = "cardio_interval_plans")
public class CardioIntervalPlan extends SyncableEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(nullable = false, length = 120)
    private String name;

    /**
     * Every step row of the plan, flat: the top-level items and the steps
     * inside the repeat blocks alike. The nesting is read off
     * {@link CardioIntervalStep#getParent()} rather than modelled as a second
     * collection here — one owning collection means one place that cascades
     * and one place that orphan-removes.
     *
     * <p>{@code stepIndex} orders siblings, so this list is only fully
     * ordered within a parent. Whoever fills it must add a repeat block
     * before the steps that hang off it: ids are IDENTITY-generated, so
     * Hibernate inserts in iteration order and a child needs its parent's id
     * to already exist.
     */
    @OneToMany(mappedBy = "plan", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("stepIndex ASC")
    private List<CardioIntervalStep> steps = new ArrayList<>();
}
