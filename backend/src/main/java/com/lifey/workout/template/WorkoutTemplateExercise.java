package com.lifey.workout.template;

import com.lifey.common.domain.BaseEntity;
import com.lifey.workout.exercise.Exercise;
import jakarta.persistence.Entity;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

@Entity
@Table(name = "workout_template_exercises")
public class WorkoutTemplateExercise extends BaseEntity {

    @ManyToOne
    private WorkoutTemplate workoutTemplate;

    @ManyToOne
    private Exercise exercise;

    // Getters and setters.
}
