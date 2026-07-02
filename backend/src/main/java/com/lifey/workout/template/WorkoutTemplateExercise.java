package com.lifey.workout.template;

import com.lifey.common.domain.BaseEntity;
import com.lifey.workout.exercise.Exercise;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@Entity
@Table(name = "workout_template_exercises")
public class WorkoutTemplateExercise extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "workout_template_id", nullable = false)
    private WorkoutTemplate workoutTemplate;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "exercise_id", nullable = false)
    private Exercise exercise;

    @Column(name = "target_sets")
    private Integer targetSets;

    @Column(name = "sort_order", nullable = false)
    private int sortOrder;
}
