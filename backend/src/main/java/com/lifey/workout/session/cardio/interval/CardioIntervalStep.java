package com.lifey.workout.session.cardio.interval;

import com.lifey.common.domain.BaseEntity;
import com.lifey.workout.session.cardio.IntervalIntensity;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.util.ArrayList;
import java.util.List;

/**
 * One item of a {@link CardioIntervalPlan}: either a section (a duration at a
 * target intensity) or the repeat block that holds sections — docs/cardio/61
 * §3 M37, "4× (4:00 kemény + 3:00 könnyű)".
 *
 * <p>Nesting is exactly one level deep: a {@link IntervalStepType#REPEAT} row
 * is always top-level, which the {@code cardio_interval_steps_shape_ck} DB
 * constraint (V70) enforces, not just this class.
 *
 * <p>Never independently delta-synced — a step-only edit must bump the
 * parent plan's {@code updatedAt}, same caveat as WorkoutTemplate's exercise
 * links (docs/16-delta-sync-rollout.md §2.3).
 */
@Getter
@Setter
@Entity
@Table(name = "cardio_interval_steps")
public class CardioIntervalStep extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "plan_id", nullable = false)
    private CardioIntervalPlan plan;

    /**
     * The repeat block this step sits in; null for a top-level item. The DB
     * additionally ties this to {@link #plan} through a composite foreign key
     * (V70), so a step can't be re-parented into another plan.
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "parent_step_id")
    private CardioIntervalStep parent;

    /**
     * Read-only view of a repeat block's own steps, in playback order. Writes
     * go through {@link CardioIntervalPlan#getSteps()} — this side neither
     * cascades nor orphan-removes.
     */
    @OneToMany(mappedBy = "parent")
    @OrderBy("stepIndex ASC")
    private List<CardioIntervalStep> children = new ArrayList<>();

    /** 0-based position among its siblings (within the same parent), not within the plan. */
    @Column(name = "step_index", nullable = false)
    private int stepIndex;

    @Enumerated(EnumType.STRING)
    @Column(name = "step_type", nullable = false, length = 16)
    private IntervalStepType stepType;

    /** "Bemelegítés" — optional; without it the intensity label carries the meaning. */
    @Column(length = 60)
    private String name;

    /** Non-null exactly for a {@link IntervalStepType#STEP}. */
    @Enumerated(EnumType.STRING)
    @Column(length = 16)
    private IntervalIntensity intensity;

    /** Non-null exactly for a {@link IntervalStepType#STEP}; always positive. */
    @Column(name = "duration_seconds")
    private Integer durationSeconds;

    /** Non-null exactly for a {@link IntervalStepType#REPEAT}: how many times its children run. */
    @Column(name = "repeat_count")
    private Integer repeatCount;
}
