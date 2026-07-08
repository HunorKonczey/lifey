package com.lifey.trainer.entity;

import com.lifey.common.domain.BaseEntity;
import com.lifey.trainer.Recurrence;
import com.lifey.user.User;
import com.lifey.workout.template.WorkoutTemplate;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;

/**
 * A trainer-defined recurrence (docs/personal_trainer/09-utemezett-edzesek-domain-backend.md)
 * whose occurrences are materialized up front as {@link com.lifey.workout.session.WorkoutSession}
 * rows (scheduledFor set, startedAt null) rather than computed on read.
 */
@Getter
@Setter
@Entity
@Table(name = "workout_schedules")
public class WorkoutSchedule extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "trainer_id", nullable = false)
    private User trainer;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "client_id", nullable = false)
    private User client;

    /** Not an FK: the trainer's original may be soft-deleted after the schedule is created. */
    @Column(name = "source_template_id", nullable = false)
    private Long sourceTemplateId;

    /** The client's copy of the template — occurrences are started from this, not the trainer's original. */
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "client_template_id", nullable = false)
    private WorkoutTemplate clientTemplate;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 8)
    private Recurrence recurrence;

    /** WEEKLY only: comma-separated ISO day-of-week abbreviations, e.g. "MON,THU". */
    @Column(name = "days_of_week", length = 32)
    private String daysOfWeek;

    /**
     * Optional wall-clock time of day, inherited by every occurrence; no time zone —
     * "the client's clock reads this time", wherever that is.
     */
    @Column(name = "time_of_day")
    private LocalTime timeOfDay;

    @Column(name = "start_date", nullable = false)
    private LocalDate startDate;

    /** ONCE: equals startDate; otherwise <= startDate + 3 months. */
    @Column(name = "end_date", nullable = false)
    private LocalDate endDate;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "cancelled_at")
    private Instant cancelledAt;
}
