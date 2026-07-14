package com.lifey.trainer.entity;

import com.lifey.common.domain.BaseEntity;
import com.lifey.user.User;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

/**
 * A trainer-owned, reusable multi-week program blueprint
 * (docs/34-multi-week-program-plan.md). Assigning it to a client
 * (see {@link ProgramAssignment}) materializes a snapshot of {@link #workouts}
 * as scheduled {@code workout_sessions} rows; later edits here do not
 * retro-edit an in-flight assignment.
 */
@Getter
@Setter
@Entity
@Table(name = "training_programs")
public class TrainingProgram extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(nullable = false, length = 120)
    private String name;

    @Column(name = "weeks_count", nullable = false)
    private int weeksCount;

    @OneToMany(mappedBy = "program", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<ProgramWorkout> workouts = new ArrayList<>();

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(name = "deleted_at")
    private Instant deletedAt;
}
