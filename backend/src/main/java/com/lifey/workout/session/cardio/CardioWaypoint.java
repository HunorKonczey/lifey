package com.lifey.workout.session.cardio;

import com.lifey.common.domain.BaseEntity;
import com.lifey.workout.session.WorkoutSession;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

/**
 * One point the user marked along a hike's route (docs/cardio/60 §7 C8.1,
 * docs/cardio/61 §4 M41). Position and altitude only — no distance or
 * elapsed-time columns: those are derived client-side from the session's own
 * local track points, the same source the elevation profile reads from, so
 * this row never carries a second copy that could disagree with it.
 *
 * <p>Computed client-side at the moment the user taps the marker button and
 * synced as a whole — same never-independently-synced caveat as
 * {@link CardioSplit}, and the same privacy tier as the route polyline
 * (docs/cardio/54-cardio-gps-route-plan.md): a coarse, deliberately-kept
 * position, not part of the raw GPS track, which never leaves the phone
 * (docs/cardio/52 D-C1.2).
 */
@Getter
@Setter
@Entity
@Table(name = "cardio_waypoints")
public class CardioWaypoint extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "workout_session_id", nullable = false)
    private WorkoutSession workoutSession;

    /** 0-based, in the order the waypoints were marked. Unique per session. */
    @Column(name = "waypoint_index", nullable = false)
    private int waypointIndex;

    @Column(nullable = false)
    private double latitude;

    @Column(nullable = false)
    private double longitude;

    /** Null when the GPS fix at the moment of marking carried no altitude. */
    @Column(name = "altitude_meters")
    private Double altitudeMeters;

    /**
     * Always null in V1 (docs/cardio/60 Q-D5) — there is no input field for it
     * yet; the column exists for the planned V2 rename-after-the-fact feature.
     */
    @Column(length = 120)
    private String label;
}
