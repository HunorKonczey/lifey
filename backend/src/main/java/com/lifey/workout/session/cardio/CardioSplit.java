package com.lifey.workout.session.cardio;

import com.lifey.common.domain.BaseEntity;
import com.lifey.workout.session.WorkoutSession;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

/**
 * One section of a cardio {@link WorkoutSession}: either a per-km/lap split
 * of a DISTANCE-family session (docs/cardio/51 §3.2, docs/cardio/52 §2.3) or
 * one executed section of an interval plan on the indoor bike
 * (docs/cardio/60 D-C7.1) — told apart by {@link #splitType}. The interval
 * execution deliberately has no table of its own: this row already stores
 * exactly that shape (an ordered index plus a duration), so the summary's
 * split list renders both with no change of its own.
 *
 * <p>Computed client-side at close time — from the filtered GPS track for a
 * DISTANCE split, from the interval player for an INTERVAL one — and synced
 * as a whole: the server never derives these itself (it never sees the raw
 * track, see docs/cardio/52 D-C1.2), so an update always replaces the entire
 * list for a session rather than patching individual rows.
 */
@Getter
@Setter
@Entity
@Table(name = "cardio_splits")
public class CardioSplit extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "workout_session_id", nullable = false)
    private WorkoutSession workoutSession;

    /** 0-based position within the session's split list. Unique per session. */
    @Column(name = "split_index", nullable = false)
    private int splitIndex;

    /**
     * DISTANCE (the original, per-km split) or INTERVAL. Defaults to DISTANCE
     * so a client that predates intervals behaves exactly as before; existing
     * rows got the same default via the V70 migration.
     */
    @Enumerated(EnumType.STRING)
    @Column(name = "split_type", nullable = false, length = 16)
    private SplitType splitType = SplitType.DISTANCE;

    /**
     * Usually exactly 1000 (one km), but not assumed — the last split of a
     * run is shorter. Required for a DISTANCE split (DB constraint), null for
     * an INTERVAL one on a machine that reports no distance, which is most of
     * them.
     */
    @Column(name = "distance_meters")
    private Double distanceMeters;

    @Column(name = "duration_seconds", nullable = false)
    private int durationSeconds;

    /** Net elevation change over the split; null when no altitude data was available. */
    @Column(name = "elevation_delta_m")
    private Double elevationDeltaM;

    @Column(name = "avg_heart_rate")
    private Double avgHeartRate;

    /** Average power over the section; null without a watt-reporting machine (docs/cardio/51 §3.3). */
    @Column(name = "avg_watts")
    private Double avgWatts;

    /**
     * The target effort this section was run at — INTERVAL splits only, null
     * for a DISTANCE one (DB constraint). Stored on the execution rather than
     * looked up from the plan: the plan stays editable and deletable, and a
     * summary that silently relabelled its sections months later would be
     * lying about what was done.
     */
    @Enumerated(EnumType.STRING)
    @Column(length = 16)
    private IntervalIntensity intensity;
}
