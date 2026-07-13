package com.lifey.trainer.entity;

import com.lifey.common.domain.BaseEntity;
import com.lifey.user.User;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;
import java.time.LocalDate;

/**
 * The fact "this {@link TrainingProgram} was started for this client on this
 * date" (docs/34-multi-week-program-plan.md) — a materialized snapshot, not a
 * live link: {@link #programName} is denormalized so history survives the
 * program being renamed or soft-deleted. Occurrences are generated once, at
 * assignment time, as plain {@code workout_sessions} rows carrying this row's
 * id in {@code program_assignment_id}.
 */
@Getter
@Setter
@Entity
@Table(name = "program_assignments")
public class ProgramAssignment extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "program_id", nullable = false)
    private TrainingProgram program;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "trainer_id", nullable = false)
    private User trainer;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "client_id", nullable = false)
    private User client;

    @Column(name = "program_name", nullable = false, length = 120)
    private String programName;

    /** Always a Monday. */
    @Column(name = "start_date", nullable = false)
    private LocalDate startDate;

    /** {@code startDate + weeksCount * 7 - 1}. */
    @Column(name = "end_date", nullable = false)
    private LocalDate endDate;

    @Column(name = "assigned_at", nullable = false)
    private Instant assignedAt;

    @Column(name = "cancelled_at")
    private Instant cancelledAt;
}
