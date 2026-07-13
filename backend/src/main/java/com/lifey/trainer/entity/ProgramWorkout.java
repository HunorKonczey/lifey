package com.lifey.trainer.entity;

import com.lifey.common.domain.BaseEntity;
import com.lifey.workout.template.WorkoutTemplate;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalTime;

/**
 * A single week/day slot in a {@link TrainingProgram}'s grid — one workout
 * template, at most once per (week, day) cell (see
 * docs/34-multi-week-program-plan.md).
 */
@Getter
@Setter
@Entity
@Table(name = "program_workouts")
public class ProgramWorkout extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "program_id", nullable = false)
    private TrainingProgram program;

    /** 1-based; must be {@code <= program.weeksCount}. */
    @Column(name = "week_number", nullable = false)
    private int weekNumber;

    /** ISO day-of-week abbreviation, e.g. "MON" — same code convention as {@link WorkoutSchedule#getDaysOfWeek()}. */
    @Column(name = "day_of_week", nullable = false, length = 3)
    private String dayOfWeek;

    /** One of the trainer's own workout templates. */
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "template_id", nullable = false)
    private WorkoutTemplate template;

    /** Optional wall-clock time, inherited by the occurrence generated from this slot. */
    @Column(name = "time_of_day")
    private LocalTime timeOfDay;

    /** Optional trainer-facing progression note (e.g. "top set +2.5 kg") — not shown to the client. */
    @Column(length = 500)
    private String note;
}
