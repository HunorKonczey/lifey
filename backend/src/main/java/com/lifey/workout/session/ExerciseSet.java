package com.lifey.workout.session;

import com.lifey.common.domain.BaseEntity;
import com.lifey.workout.exercise.Exercise;
import jakarta.persistence.Entity;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

@Entity
@Table(name = "exercise_sets")
public class ExerciseSet extends BaseEntity {

    @ManyToOne
    private WorkoutSession workoutSession;

    @ManyToOne
    private Exercise exercise;

    private Integer reps;

    private Double weight;

    // Getters and setters.
}
