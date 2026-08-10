package com.lifey.workout.session.cardio;

import com.lifey.common.domain.BaseEntity;
import com.lifey.workout.session.WorkoutSession;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

/**
 * Cardio metrics for a CARDIO-kind {@link WorkoutSession} (docs/cardio/51
 * D-C.2 hybrid storage: a few common columns live on {@code workout_sessions}
 * itself, everything family-specific lives here in one table rather than one
 * per family — see docs/cardio/52 §2.2). One row per cardio session.
 *
 * <p>Never independently delta-synced (docs/cardio/52 §4): only the parent
 * {@link WorkoutSession#getUpdatedAt()} drives sync, so any write here must
 * also bump it, same as {@code exercise_sets}/{@code workout_session_exercises}
 * already have to.
 */
@Getter
@Setter
@Entity
@Table(name = "cardio_details")
public class CardioDetails extends BaseEntity {

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "workout_session_id", nullable = false, unique = true)
    private WorkoutSession workoutSession;

    // -- DISTANCE + MACHINE ---------------------------------------------

    @Column(name = "distance_meters")
    private Double distanceMeters;

    @Column(name = "elevation_gain_meters")
    private Double elevationGainMeters;

    @Column(name = "elevation_loss_meters")
    private Double elevationLossMeters;

    @Column(name = "max_altitude_meters")
    private Double maxAltitudeMeters;

    @Column(name = "steps")
    private Integer steps;

    /** Steps/min for running, rpm for the indoor bike — see docs/cardio/51 §3. */
    @Column(name = "avg_cadence")
    private Double avgCadence;

    @Column(name = "max_cadence")
    private Double maxCadence;

    // -- MACHINE ----------------------------------------------------------

    @Column(name = "avg_watts")
    private Double avgWatts;

    @Column(name = "max_watts")
    private Double maxWatts;

    @Column(name = "resistance_level")
    private Integer resistanceLevel;

    /**
     * The machine's own displayed calorie count, kept apart from the phone/
     * watch measurement — never automatically added to daily active calories
     * (docs/cardio/51 Q4).
     */
    @Column(name = "device_calories")
    private Double deviceCalories;

    // -- Shared physiological ----------------------------------------------

    @Column(name = "max_heart_rate")
    private Double maxHeartRate;

    @Column(name = "hr_zone1_seconds")
    private Integer hrZone1Seconds;

    @Column(name = "hr_zone2_seconds")
    private Integer hrZone2Seconds;

    @Column(name = "hr_zone3_seconds")
    private Integer hrZone3Seconds;

    @Column(name = "hr_zone4_seconds")
    private Integer hrZone4Seconds;

    @Column(name = "hr_zone5_seconds")
    private Integer hrZone5Seconds;

    // -- GAME ---------------------------------------------------------------

    /** Subjective 1-5 intensity — see docs/cardio/51 §3.4. DB-checked range. */
    @Column(name = "intensity")
    private Integer intensity;

    /** {@code INDOOR} or {@code OUTDOOR} — drives GPS and the watch's activity locationType (docs/cardio/55 D-C5.1). DB-checked. */
    @Column(name = "venue")
    private String venue;

    /** Free-text format code (e.g. {@code 5V5}, {@code SMALL_SIDED}, {@code PRACTICE}). */
    @Column(name = "game_format")
    private String gameFormat;

    /** Basketball: points. Football: goals. */
    @Column(name = "score_points")
    private Integer scorePoints;

    @Column(name = "score_assists")
    private Integer scoreAssists;

    @Column(name = "score_rebounds")
    private Integer scoreRebounds;

    // -- Provenance (docs/cardio/51 R8) --------------------------------------

    /** {@code MEASURED}, {@code MANUAL}, or {@code DEVICE} — a manual override always wins. */
    @Column(name = "distance_source")
    private String distanceSource;

    @Column(name = "calories_source")
    private String caloriesSource;

    // -- Route (docs/cardio/54) ------------------------------------------------

    /** Encoded, simplified polyline — raw GPS points never leave the phone. */
    @Column(name = "route_polyline")
    private String routePolyline;

    @Column(name = "route_point_count")
    private Integer routePointCount;
}
