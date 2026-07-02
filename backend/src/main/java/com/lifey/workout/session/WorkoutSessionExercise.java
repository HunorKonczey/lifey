package com.lifey.workout.session;

import com.lifey.common.domain.BaseEntity;
import com.lifey.workout.exercise.Exercise;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

/**
 * An exercise planned for a session — e.g. copied in from a template at
 * creation time — independent of how many sets have actually been logged for
 * it. See {@link WorkoutSession#getPlannedExercises()}.
 */
@Getter
@Setter
@Entity
@Table(name = "workout_session_exercises")
public class WorkoutSessionExercise extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "workout_session_id", nullable = false)
    private WorkoutSession workoutSession;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "exercise_id", nullable = false)
    private Exercise exercise;
}
