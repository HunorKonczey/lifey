package com.lifey.workout.session.cardio;

import com.lifey.common.domain.BaseEntity;
import com.lifey.workout.session.WorkoutSession;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

/**
 * One per-km/lap split of a DISTANCE-family cardio {@link WorkoutSession}
 * (docs/cardio/51 §3.2, docs/cardio/52 §2.3). Computed client-side at close
 * time from the filtered GPS track and synced as a whole — the server never
 * derives these itself (it never sees the raw track, see
 * docs/cardio/52 D-C1.2), so an update always replaces the entire list for a
 * session rather than patching individual rows.
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

    /** Usually exactly 1000 (one km), but not assumed — the last split of a run is shorter. */
    @Column(name = "distance_meters", nullable = false)
    private double distanceMeters;

    @Column(name = "duration_seconds", nullable = false)
    private int durationSeconds;

    /** Net elevation change over the split; null when no altitude data was available. */
    @Column(name = "elevation_delta_m")
    private Double elevationDeltaM;

    @Column(name = "avg_heart_rate")
    private Double avgHeartRate;
}
