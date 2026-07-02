package com.lifey.workout.session;

import com.lifey.common.domain.BaseEntity;
import com.lifey.workout.exercise.Exercise;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

@Getter
@Setter
@Entity
@Table(name = "exercise_sets")
public class ExerciseSet extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "workout_session_id", nullable = false)
    private WorkoutSession workoutSession;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "exercise_id", nullable = false)
    private Exercise exercise;

    @Column(nullable = false)
    private int reps;

    @Column(nullable = false)
    private double weight;

    @Column(name = "performed_at", nullable = false)
    private Instant performedAt;
}
