package com.lifey.workout.session;

import com.lifey.common.domain.SyncableEntity;
import com.lifey.user.User;
import com.lifey.workout.template.WorkoutTemplate;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

/**
 * Only the parent WorkoutSession is delta-synced (see
 * docs/16-delta-sync-rollout.md) — sets and planned exercises are never
 * independently tombstoned, so any child-only edit must explicitly bump
 * {@code updatedAt} (see WorkoutSessionServiceImpl#update, which cannot rely
 * on Hibernate dirty-checking a session scalar field when only a child
 * collection changed).
 */
@Getter
@Setter
@Entity
@Table(name = "workout_sessions")
public class WorkoutSession extends SyncableEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "started_at", nullable = false)
    private Instant startedAt;

    @Column(name = "finished_at")
    private Instant finishedAt;

    @OneToMany(mappedBy = "workoutSession", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("performedAt ASC")
    private List<ExerciseSet> sets = new ArrayList<>();

    /**
     * Exercises planned for this session (e.g. copied in from a template at
     * creation time), independent of how many {@link #sets} have been logged
     * for them yet. A plain snapshot — no link back to the source template.
     */
    @OneToMany(mappedBy = "workoutSession", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<WorkoutSessionExercise> plannedExercises = new ArrayList<>();

    /**
     * Active energy burned (kcal) over the workout, as reported by Apple Health.
     */
    @Column(name = "active_calories")
    private Double activeCalories;

    /**
     * Average heart rate (bpm) over the workout interval, as reported by Apple Health.
     */
    @Column(name = "average_heart_rate")
    private Double averageHeartRate;

    /**
     * HKWorkout UUID. Non-null means this session was paired with an Apple Health workout.
     */
    @Column(name = "health_workout_id")
    private String healthWorkoutId;

    /**
     * The template this session was started from, if any.
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "template_id")
    private WorkoutTemplate template;

    /**
     * Snapshot of the template's name at the time this session was started,
     * so the session still shows what it was called even if the template is
     * later renamed or deleted.
     */
    @Column(name = "template_name")
    private String templateName;
}
